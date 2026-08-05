# This Terraform configuration file defines output variables for the EKS (Elastic Kubernetes Service) cluster and related resources created in the module. 
# These outputs provide essential information about the cluster, such as its name, endpoint, certificate authority data, OIDC provider ARN, ECR repository URL, and VPC ID. 
# These outputs can be used by other Terraform configurations or modules to reference the created resources.
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for this cluster, needed to build an IAM trust policy for any future IRSA-based role."
  value       = module.eks.oidc_provider_arn
}


output "vpc_id" {
  value = module.vpc.vpc_id
}
