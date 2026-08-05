variable "additional_access_entries" {
  description = "Extra IAM principals needing Kubernetes RBAC access -- supplied via a local, gitignored terraform.tfvars, never committed. See terraform.tfvars.example."
  type = map(object({
    principal_arn = string
    policy_arn    = string
  }))
  default = {}
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS API server's public endpoint. Override via local terraform.tfvars to restrict to known IPs."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
