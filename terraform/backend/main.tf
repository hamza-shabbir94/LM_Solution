# This Terraform configuration file sets up an S3 bucket to be used as a backend for storing Terraform state files.
# It includes the necessary provider configuration for AWS, and defines resources for the S3 bucket, versioning, server-side encryption, and public access block settings.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.57.1"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# ------------------------------------------------------------------
# S3 bucket for Terraform state storage
# ------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = "lm-backend" # must be globally unique -- change before applying

  # Prevents `terraform destroy` from ever accidentally deleting the
  # bucket every environment's state lives in.
  lifecycle {
    prevent_destroy = true
  }
}
# ------------------------------------------------------------------
# S3 bucket versioning to allow rollback of state files
# ------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled" # lets a corrupted/bad state file be rolled back to a previous version
  }
}

# ------------------------------------------------------------------
# Server-side encryption and public access block settings for the S3 bucket
# ------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------------------
# Block public access to the S3 bucket to ensure state files are not exposed publicly
# ------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

