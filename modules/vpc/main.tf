variable "app_config" {}
variable "name" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18"

  name = var.name
  cidr = var.app_config.vpc.cidr_block

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.app_config.vpc.cidr_block, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.app_config.vpc.cidr_block, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.app_config.vpc.cidr_block, 8, k + 52)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway      = true
  single_nat_gateway      = false
  reuse_nat_ips           = true             # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids     = aws_eip.nat.*.id # <= IPs specified here as input to the module
  map_public_ip_on_launch = false
  enable_vpn_gateway      = true

  manage_default_network_acl  = true
  default_network_acl_tags    = { Name = "${var.name}-default" }
  default_network_acl_ingress = []
  default_network_acl_egress  = []

  manage_default_route_table = true
  default_route_table_tags   = { Name = "${var.name}-default" }

  manage_default_security_group  = true
  default_security_group_tags    = { Name = "${var.name}-default" }
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_log_format                             = "$${interface-id} $${srcaddr} $${srcport} $${pkt-src-aws-service} $${dstaddr} $${dstport} $${pkt-dst-aws-service} $${protocol} $${flow-direction} $${traffic-path} $${action} $${log-status} $${subnet-id} $${az-id} $${sublocation-type} $${sublocation-id}"


  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  public_dedicated_network_acl = true
  public_inbound_acl_rules = [
    {
      # All access from VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
    },
    {
      # HTTP IPv4
      "rule_number" : 120,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 80,
      "to_port" : 80,
      "rule_action" : "allow"
    },
    {
      # Ephemeral ports
      "rule_number" : 130,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    },
  ]
  public_outbound_acl_rules = concat([for rule_offset, cidr_block in module.vpc.private_subnets_cidr_blocks :
    {
      # All access to private subnets
      "rule_number" : 100 + rule_offset,
      "cidr_block" : cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    }],
    [{
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
      },
      {
        # HTTP IPv4
        "rule_number" : 120,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 80,
        "to_port" : 80,
        "rule_action" : "allow"
      },
      {
        # NTP IPv4
        "rule_number" : 130,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 123,
        "to_port" : 123,
        "rule_action" : "allow"
      },
      {
        # NTP IPv4
        "rule_number" : 131,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "udp",
        "from_port" : 123,
        "to_port" : 123,
        "rule_action" : "allow"
      },
      {
        # Ephemeral ports
        "rule_number" : 140,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 1024,
        "to_port" : 65535,
        "rule_action" : "allow"
      },
  ])

  private_dedicated_network_acl = true
  private_inbound_acl_rules = [
    {
      # All access from VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # Ephemeral ports
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    }
  ]
  private_outbound_acl_rules = [
    {
      # All access to VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
    },
    {
      # HTTP IPv4
      "rule_number" : 120,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 80,
      "to_port" : 80,
      "rule_action" : "allow"
    },
    {
      # NTP TCP IPv4
      "rule_number" : 130,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 123,
      "to_port" : 123,
      "rule_action" : "allow"
    },
    {
      # NTP UDP IPv4
      "rule_number" : 131,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "udp",
      "from_port" : 123,
      "to_port" : 123,
      "rule_action" : "allow"
    },
    {
      # Return/response traffic ephemeral ports
      "rule_number" : 140,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    },
  ]

  create_database_subnet_route_table = true
  database_dedicated_network_acl     = true
  database_inbound_acl_rules = concat([for rule_offset, cidr_block in module.vpc.public_subnets_cidr_blocks :
    {
      # Deny all access from public subnets
      "rule_number" : 100 + rule_offset,
      "cidr_block" : cidr_block
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "deny"
    }],
    [{
      # Allow all (remaining) PostgreSQL access from VPC CDIR
      "rule_number" : 110,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "tcp",
      "from_port" : 5432,
      "to_port" : 5432,
      "rule_action" : "allow"
      },
  ])
  database_outbound_acl_rules = concat([for rule_offset, cidr_block in module.vpc.public_subnets_cidr_blocks :
    {
      # Deny all access to public subnets
      "rule_number" : 100 + rule_offset,
      "cidr_block" : cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "deny"
    }],
    [{
      # Allow all (remaining) ephemeral ports to VPC CIDR
      "rule_number" : 110,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
      }
  ])

  # tags = merge(provider.aws.tags,{})
}

resource "aws_eip" "nat" {
  count = 3

  vpc = true
}

