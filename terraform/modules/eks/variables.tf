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


variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS API server's public endpoint. Defaults to open (matches the module's own default) so this stays usable out of the box; restrict to known IPs (office, VPN, CI runner) via a local .tfvars for real use, rather than leaving it open long-term."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_access_entries" {
  description = "Extra IAM principals needing Kubernetes RBAC access -- supplied via a local, gitignored terraform.tfvars, never committed. See terraform.tfvars.example."
  type = map(object({
    principal_arn = string
    policy_arn    = string
  }))
  default = {}
}

