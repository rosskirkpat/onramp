variable "app_config" {}
variable "provider_arn" {}
variable "cluster_id" {}
variable "node_iam_role_arns" {}

module "vpc_cni_irsa_role" {
  source  = "terraform-aws-modules/iam/aws/modules/iam-role-for-service-accounts-eks"
  version = "~> 5.9"

  role_name_prefix      = "VPC-CNI-IRSA-"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn = var.provider_arn
      namespace_service_accounts = [
        "kube-system:aws-node",
      ]
    }
  }
}

module "karpenter_irsa_role" {
  source = "terraform-aws-modules/iam/aws/modules/iam-role-for-service-accounts-eks"

  role_name                          = "karpenter_controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id         = var.cluster_id
  karpenter_controller_node_iam_role_arns = var.node_iam_role_arns

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn = var.provider_arn
      namespace_service_accounts = [
        "default:${var.app_config.service_account_name}",
        "canary:${var.app_config.service_account_name}",
      ]
    }
  }
}