# ------------------------------------------------------------------
# Bootstrap: creates the S3 bucket + DynamoDB lock table that every
# environment's own backend.s3 block then points at.
#
# This config deliberately has NO remote backend of its own -- it
# uses local state, and is run manually, once, before any environment
# is applied for the first time. It cannot use the S3 backend it's
# creating (chicken-and-egg), so this is the one exception to
# "always use remote state" in this repo.
#
# Run once per AWS account:
#   cd terraform/bootstrap && terraform init && terraform apply
# ------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "lm-backend" # must be globally unique -- change before applying

  # Prevents `terraform destroy` from ever accidentally deleting the
  # bucket every environment's state lives in.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled" # lets a corrupted/bad state file be rolled back to a previous version
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

