variable "app_config" {}
variable "vpc_id" {}
variable "security_group_id" {}
variable "private_route_table_ids" {}
variable "private_subnets_cidr_blocks" {}
variable "private_subnets" {}
variable "name" {}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws/modules/vpc-endpoints"
  version = "~> 3.0"

  vpc_id             = var.vpc_id
  security_group_ids = [var.security_group_id]

  endpoints = merge({
    # ECR images are stored on S3
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = var.private_route_table_ids
      tags = merge(provider.aws.tags, {
        Name = "${local.name}-s3"
      })
    }
    },
    { for service in toset(["autoscaling", "ecr.api", "ecr.dkr", "ec2", "ec2messages", "sts", "logs", "ssm", "ssmmessages"]) :
      replace(service, ".", "_") =>
      {
        service             = service
        subnet_ids          = var.private_subnets
        private_dns_enabled = true
        tags = merge(aws.tags, {
          Name = "${var.name}-${service}"
        })
      }
  })
}


module "vpc_endpoints_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC endpoint access"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "VPC CIDR HTTPS"
      cidr_blocks = join(",", var.private_subnets_cidr_blocks)
    },
  ]
}