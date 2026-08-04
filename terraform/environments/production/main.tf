terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
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
  source = "../../modules/eks-platform"

  environment      = "production"
  aws_region       = "eu-central-1"
  vpc_cidr         = "10.2.0.0/16"

  node_instance_types = ["m7i-flex.large"]
  node_min_size       = 2
  node_max_size       = 10
  node_desired_size   = 3
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "ecr_repository_url" {
  value = module.platform.ecr_repository_url
}
