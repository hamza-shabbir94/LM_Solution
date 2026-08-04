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
  description = "OIDC provider ARN for this cluster, needed to build an IAM trust policy for any future IRSA-based role (e.g. if a service later needs to call AWS APIs directly, such as an in-cluster load balancer controller). Not consumed by anything in this module today -- see SOLUTION.md 'if I had more time'."
  value       = module.eks.oidc_provider_arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api_service.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
