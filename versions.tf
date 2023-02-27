terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16"
    }
  }

  backend "s3" {
    # Update the remote backend below to support your environment
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-architecture/self-managed-node-group/us-east-1/terraform.tfstate"
    region         = "us-gov-east-1"
    dynamodb_table = "clowd-haus-terraform-state"
    encrypt        = true
  }
}