# This Terraform configuration file defines output variables for the S3 bucket used to store Terraform state files.
output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}
