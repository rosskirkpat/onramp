variable "app_config" {}

module "iam_eks_role" {
  source = "terraform-aws-modules/iam/aws/modules/iam-eks-role"

  role_name = var.app_config.rbac_role_name

  cluster_service_accounts = {
    # TODO pull cluster name from eks module
    # TODO paramaterize service account name
    "cluster1" = ["default:${var.app_config.service_account_name}"]
  }
}

# TODO migrate to using a terraform map and then json encode it
resource "aws_iam_role" "entity" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}