terraform {
  backend "s3" {
    bucket         = "lm-backend"
    key            = "api-service/production/terraform.tfstate"
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

  environment      = "production"
  aws_region       = "eu-central-1"
  vpc_cidr         = "10.2.0.0/16"

  node_instance_types = ["t3.large"]
  node_min_size       = 3
  node_max_size       = 10
  node_desired_size   = 3
  additional_access_entries = var.additional_access_entries
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "ecr_repository_url" {
  value = module.platform.ecr_repository_url
}

