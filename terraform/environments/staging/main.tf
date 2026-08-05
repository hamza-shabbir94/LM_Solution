terraform {
  backend "s3" {
    bucket         = "lm-backend"
    key            = "api-service/staging/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "platform" {
  source = "../../modules/eks"

  environment = "staging"
  aws_region  = "eu-central-1"
  vpc_cidr    = "10.1.0.0/16"

  node_instance_types = ["t3.medium"]
  node_min_size       = 2
  node_max_size       = 5
  node_desired_size   = 2
  additional_access_entries = var.additional_access_entries
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
}

output "cluster_name" {
  value = module.platform.cluster_name
}


