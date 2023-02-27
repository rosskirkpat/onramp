variable "app_config" {}
variable "name" {}
variable "private_subnets" {}
variable "private_subnets_cidr_blocks" {}
variable "vpc_cidr_block" {}
variable "vpc_id" {}
variable "cloudwatch_log_group" {}
variable "server_certificate_arn" {}
variable "eks_sg_id" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

resource "aws_ec2_client_vpn_endpoint" "entity" {
  description            = var.name
  client_cidr_block      = var.app_config.vpn.client_cidr_block
  split_tunnel           = true
  dns_servers            = [cidrhost(var.vpc_cidr_block, 2), var.app_config.vpn.dns_servers]
  server_certificate_arn = data.aws_acm_certificate.entity.arn
  session_timeout_hours  = var.app_config.vpn.session_timeout_hours

  vpc_id = module.vpc.vpc_id
  security_group_ids = [
    module.client_vpn_sg.security_group_id,
    var.eks_sg_id, # allows access to API server for kubectl commands
  ]

  authentication_options {
    type              = "federated-authentication"
    saml_provider_arn = "arn:${local.partition}:iam::${local.account_id}:saml-provider/${var.name}-client-vpn"
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group = aws_cloudwatch_log_group.client_vpn.id
  }

  tags = merge(provider.aws.tags, {
    Name = "${var.name}-client-vpn"
  })
}

resource "aws_ec2_client_vpn_network_association" "entity" {
  for_each = toset(var.private_subnets)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.entity.id
  subnet_id              = each.value
}

resource "aws_ec2_client_vpn_authorization_rule" "entity" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.entity.id
  target_network_cidr    = var.vpc_cidr_block
  description            = "Full VPC access"
  authorize_all_groups   = true
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "${var.name}-client-vpn"
  retention_in_days = var.app_config.vpn.retention_in_days
}

module "client_vpn_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "aws-client-vpn"
  description = "Security group for AWS Client VPN"
  vpc_id      = var.vpc_id

  egress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      description = "Access PostgreSQL databases"
      cidr_blocks = join(",", module.vpc.database_subnets_cidr_blocks)
    },
    {
      rule        = "https-443-tcp"
      description = "Access HTTPS/443 for VPC endpoints"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]
}