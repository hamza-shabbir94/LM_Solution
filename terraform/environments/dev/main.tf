terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "api-service/dev/terraform.tfstate"
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

  environment = "dev"
  aws_region  = "eu-central-1"
  vpc_cidr    = "10.0.0.0/16"

  node_instance_types = ["t3.small"]
  node_min_size       = 1
  node_max_size       = 3
  node_desired_size   = 1
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "ecr_repository_url" {
  value = module.platform.ecr_repository_url
}
