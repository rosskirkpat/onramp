variable "aws_credentials_file" {
  description = "full path to your local AWS credentials file"
  type        = string
}

variable "aws_profile" {
  description = "Name of the profile to use from the AWS credentials file"
  type        = string
}



variable "app_config" {
  default = {
    cloud                = ""
    app_name = ""
    environment          = ""
    owner                = ""
    customer_name        = "dev" 
    org_name             = ""
    base_name_prefix     = ""
    service_account_name = ""
    rbac_role_name       = ""
    region               = "us-gov-east-1"
    base_domain          = ""
    kubernetes_version   = "1.24"
    dns_zone_id          = ""

    object_storage = {}

    vpc = {
      cidr_block = "10.0.0.0/16"
    }

    helm = {
      chart_name = ""
      chart_version = ""
      chart_namespace = ""
      chart_repository = ""
      timeout = ""
    }

    kubernetes = {
      private_cluster  = true
      cluster_name     = ""
      cp_node_type     = ""
      worker_node_type = ""
      rbac_enabled     = true # maps to enable_irsa EKS and role_based_access_control_enabled AKS
      enable_kms       = true
    }

    vpn = {
      client_cidr_block     = "172.16.0.0/20"
      dns_servers           = ["1.1.1.1", "1.0.0.1"]
      session_timeout_hours = 8
      retention_in_days     = 365
    }

    repository = {
      repository_name     = ""
      visibility          = "private"
      replication_regions = ["us-gov-west-1", "us-gov-east-1"]
    }

    managed_kubernetes = {
      cluster_addons = {
        coredns    = {}
        kube-proxy = {}
        cni        = {}
      }
    }
  }
}

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

  cluster_name     = lower(join("-", [var.app_config.base_name_prefix, var.app_config.customer_name]))
  base_name_prefix = "${var.app_config.app_name}-${var.app_config.environment}"
}



variable "managed_nodes" {
  type = map(object({
    count     = optional(number)
    type      = string
    disk_size = number
  }))
  default = {
    controlplane = {
      disk_size = 100
      type      = ""
    }
    worker = {
      count     = 3
      disk_size = 100
      type      = ""
    }
  }
}

# 2cpu/8gb -> m5.large = d2as v5
# 4cpu/16gb -> m5.xlarge = d4as v5
# 8cpu/32gb -> m5.2xlarge = d8as v5

variable "node_types" {
  default = {
    aws = {
      large = {
        type = "m5.large"
      }
      xlarge = {
        type = "m5.xlarge"
      }
      "2xlarge" = {
        type = "m5.2xlarge"
      }
    }
    azure = {
      large = {
        type = "Standard_D2as_v5"
      }
      xlarge = {
        type = "Standard_D4as_v5"
      }
      "2xlarge" = {
        type = "Standard_D8as_v5"
      }
    }
  }
}
