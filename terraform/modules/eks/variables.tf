variable "environment" {
  description = "Environment name (dev, staging, production) used for naming resources and tagging."
  type        = string
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for this environment's VPC. Should be unique across environments so they don't collide."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "additional_access_entries" {
  description = "Extra IAM principals (beyond whoever runs terraform apply) that need Kubernetes RBAC access to this cluster -- e.g. engineers who browse the console under their own IAM user. Left empty by default so this module stays portable across AWS accounts; supply real values via a local, environment-specific .tfvars file that is NOT committed, rather than hardcoding an account-specific ARN here."
  type = map(object({
    principal_arn = string
    policy_arn    = string
  }))
  default = {}
}


