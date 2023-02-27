terraform {
  backend "s3" {
    bucket         = ""
    key            = ""
    region         = "us-gov-east-1"
    dynamodb_table = "terraform_state"
    profile        = ""
  }
}

provider "aws" {
  profile = ""
  region  = "us-gov-east-1"
}

resource "aws_s3_bucket" "entity" {
  bucket = ""
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  object_lock_configuration {
    object_lock_enabled = "Enabled"
  }
  tags = {
    Name = "S3 Remote Terraform State Store"
  }
}

resource "aws_dynamodb_table" "entity" {
  name           = "terraform_state"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "Name" = "DynamoDB Terraform State Lock Table"
  }
}