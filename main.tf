################################################################################
# Providers
################################################################################

provider "aws" {
  region = var.app_config.region
  # assume_role {
  #   role_arn     = "<TODO>"
  #   session_name = local.name
  # }

  access_key          = "mock_access_key"
  s3_force_path_style = true
  secret_key          = "mock_secret_key"

  default_tags = {
    tags = {
      Terraform   = "true"
      Environment = "${var.app_config.environment}"
      Owner       = "${var.app_config.owner}"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
  # private registry
  # registry {
  #   url = "oci://private.registry"
  #   username = "username"
  #   password = "password"
  # }
}


################################################################################
# Common Data
################################################################################

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_canonical_user_id" "current" {}
data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}
data "aws_partition" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

################################################################################
# Common Locals
################################################################################

locals {
  provider = var.cloud
  provider_config = {
    cloud            = local.provider
    node_types       = var.node_types[local.provider]
    cp_node_size     = var.node_types[local.provider].large
    worker_node_size = var.node_types[local.provider].xlarge
  }
  cp_nodes     = var.managed_nodes["controlplane"]
  worker_nodes = var.managed_nodes["worker"]

  cluster_name = lower(join(
    "-",
    var.app_config.kubernetes.cluster_name,
    var.app_config.environment,
    random_string.suffix.result
  ))

  name = lower(join(
    "-",
    var.app_config.app_name,
    "gov",
    var.app_config.environment,
    random_string.suffix.result
  ))

  kubernetes_version = var.app_config.kubernetes_version
  region             = var.app_config.region
  environment        = var.app_config.environment
  bucket_name = lower(join(
    "-",
    "s3-bucket",
    var.app_config.customer_name,
    random_string.suffix.result
  ))

  vpc_cidr = var.app_config.vpc.cidr_block
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix
}


################################################################################
# Helm Module
################################################################################

module "helm" {
  source = "modules/helm"

  app_config   = var.app_config
}


################################################################################
# Common Modules
################################################################################

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source         = "modules/vpc"
  app_config = var.app_config
  name           = local.name
  cidr           = local.vpc_cidr
  azs            = local.azs

}

################################################################################
# VPC Endpoints
################################################################################


module "vpc_endpoints" {
  source              = "modules/vpc_endpoints"
  app_config      = var.app_config
  private_subnets     = module.vpc.private_subnets
  name                = local.name
  vpc_id              = module.vpc.vpc_id
  private_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  security_group_id   = module.vpc_endpoints_sg.security_group_id
  route_table_ids     = module.vpc.private_route_table_ids

}


################################################################################
# Client VPN
################################################################################

module "vpn" {
  source = "modules/vpn"

  app_config              = var.app_config
  private_subnets             = module.vpc.private_subnets
  private_subnets_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  vpc_cidr_block              = module.vpc.vpc_cidr_block
  vpc_id                      = module.vpc.vpc_id
  server_certificate_arn      = data.aws_acm_certificate.entity.arn
  eks_sg_id                   = module.eks.node_security_group_id

}

################################################################################
# IRSA Modules
################################################################################

module "rbac" {
  source = "modules/rbac"

  app_config     = var.app_config
  provider_arn       = module.eks.oidc_provider_arn
  cluster_id         = module.eks.cluster_id
  node_iam_role_arns = module.eks.eks_managed_node_groups["default"].iam_role_arn
}

################################################################################
# EKS Module - Amazon Linux 2 + IRSA + Karpenter
################################################################################

module "managed_kubernetes" {
  source = "modules/managed_kubernetes"

  app_config           = var.app_config
  provider_config          = local.provider_config
  kms_key_id               = module.aws_kms_key.ebs.arn
  cluster_name             = local.cluster_name
  cluster_version          = local.kubernetes_version
  service_account_role_arn = module.rbac.iam_role_arn
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
}

################################################################################
# EKS Secrets Custom KMS Key
################################################################################



################################################################################
# EBS Custom KMS Key Module
################################################################################




################################################################################
# DNS Module
################################################################################
module "dns" {
  app_config = var.app_config
  domain_names   = module.acm.distinct_domain_names
  vault_instance = var.vault_instance
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
}

################################################################################
# KMS Module
################################################################################

module "kms" {
  source         = "modules/kms"
  app_config = var.app_config

  account_id = local.account_id
}


################################################################################
# ACM Module
################################################################################

module "certificates" {
  source = "modules/certificates"

  app_config = var.app_config
}


################################################################################
# IAM Module
################################################################################

# TODO create iam role for KMS module taking into account least privilege approach
# create an IAM role named my-app that can be assumed in EKS cluster cluster1 by a ServiceAccount called my-serviceaccount in the default namespace
module "iam" {
  source = "modules/iam"

  app_config = var.app_config
}



################################################################################
# S3 Module
################################################################################

module "object_storage" {
  source = "modules/object_storage"

  iam_role_arn   = aws_iam_role.entity.arn
  name           = local.name
  bucket_name    = local.bucket_name
  app_config = var.app_config

}

################################################################################
# ECR REPOSITORY Module
################################################################################

module "repository" {
  source = "modules/repository"

  name           = local.name
  customer_name  = local.customer_name
  kms_key        = modules.kms.ebs.arn
  app_config = var.app_config
}


################################################################################
# ECR REGISTRY Module
################################################################################
