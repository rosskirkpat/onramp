variable "app_config" {}
variable "cluster_name" {}
variable "kubernetes_version" {}
variable "iam_role_arn" {}
variable "private_subnets" {}
variable "vpc_id" {}
variable "provider_config" {}
variable "kms_key_id" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.5"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = var.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id      = var.vpc_id
  subnet_ids  = var.private_subnets
  enable_irsa = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    instance_types = [
      var.provider_config.cp_node_size,
      var.provider_config.worker_node_size
    ]

    # Note: We are using the IRSA created below for permissions.
    # However, we must deploy a new cluster with permissions for the VPC CNI
    # to provision IPs or else nodes will fail to join and node group creation fails.
    # This is ONLY required for creating a new cluster and can be disabled once the
    # cluster is up and running since the IRSA will be used at that point
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    default_node_group = {
      instance_types = [
        var.provider_config.cp_node_size,
        var.provider_config.worker_node_size
      ]

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 75
            volume_type = "gp3"
            encrypted   = true
            kms_key_id  = var.kms_key_id
            iops        = 3000
            throughput  = 150
          }
        }
      }

      ebs_optimized           = true
      disable_api_termination = false


      #   enable_bootstrap_user_data = true

      #   pre_bootstrap_user_data = <<-EOT
      #   EOT

      #   post_bootstrap_user_data = <<-EOT
      #     echo "who is a good little kubelet?"
      # echo "you are!"
      #   EOT

      update_config = {
        max_unavailable = 1
      }

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
    iam_role_additional_policies = {
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    }
  }
}

resource "local_file" "kubeconfig" {
  filename = "${path.root}/.kube/config"
  content  = data.template_file.kubeconfig.rendered
}