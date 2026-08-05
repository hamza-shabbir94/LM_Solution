additional_access_entries = {
  devops_user = {
    principal_arn = "arn:aws:iam::577435557149:user/devops-user"
    policy_arn    = "arn:aws:iam::aws:policy/eks/cluster-access-policy/AmazonEKSClusterAdminPolicy"
  }
}

cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
