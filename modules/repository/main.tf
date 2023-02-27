
variable "name" {}
variable "kms_key" {}
variable "app_config" {}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = lower(join(var.app_config.customer_name, var.app_config.repository.repository_name))
  repository_type = var.app_config.repository.visibility

  repository_read_write_access_arns = [data.aws_caller_identity.current.arn]
  repository_read_access_arns       = [""] # TODO create read-only ARN

  create_lifecycle_policy = false

  repository_encryption_type      = "KMS"
  repository_kms_key              = var.kms_key
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true

}


data "aws_iam_policy_document" "registry" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "ecr:ReplicateImage",
    ]

    resources = [
      module.ecr.repository_arn,
    ]
  }
}

module "ecr_registry" {
  source = "terraform-aws-modules/ecr/aws"

  create_repository = false

  # Registry Policy
  create_registry_policy = true
  registry_policy        = data.aws_iam_policy_document.registry.json

  # Registry Scanning Configuration
  manage_registry_scanning_configuration = true
  registry_scan_type                     = "ENHANCED"
  registry_scan_rules = [
    {
      scan_frequency = "SCAN_ON_PUSH"
      filter         = "*"
      filter_type    = "WILDCARD"
      }, {
      scan_frequency = "CONTINUOUS_SCAN"
      filter         = "*"
      filter_type    = "WILDCARD"
    }
  ]

  # Registry Replication Configuration
  create_registry_replication_configuration = true
  registry_replication_rules = [
    {
      destinations = [
        {
          region      = var.app_config.repository.replication_regions[0]
          registry_id = data.aws_caller_identity.current.account_id
        },
        {
          region      = var.app_config.repository.replication_regions[1]
          registry_id = data.aws_caller_identity.current.account_id
        }
      ]

      repository_filters = [{
        filter      = var.name
        filter_type = "PREFIX_MATCH"
      }]
    }
  ]
}