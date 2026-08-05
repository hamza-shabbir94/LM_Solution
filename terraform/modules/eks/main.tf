terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-api-service-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 3)]

  enable_nat_gateway = true

  single_nat_gateway = var.environment != "production"


  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.environment}-api-service" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = "1"
    "kubernetes.io/cluster/${var.environment}-api-service" = "shared"
  }
}

# ------------------------------------------------------------------
# EKS cluster + managed node group
# ------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment}-api-service"
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  iam_role_name            = "${var.environment}-api-service-cluster-role"
  iam_role_use_name_prefix = false


  enable_cluster_creator_admin_permissions = true


  access_entries = {
    for key, entry in var.additional_access_entries : key => {
      principal_arn = entry.principal_arn
      policy_associations = {
        admin = {
          policy_arn = entry.policy_arn
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }


  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # Same predictable-naming reasoning as the cluster role above.
      iam_role_name            = "${var.environment}-api-service-node-role"
      iam_role_use_name_prefix = false

      # Nodes live in private subnets only -- no public IP, no direct
      # inbound path from the internet. Outbound (e.g. pulling images)
      # goes through the NAT gateway.
      subnet_ids = module.vpc.private_subnets
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


resource "aws_ecr_repository" "api_service" {
  name                 = "${var.environment}-api-service"
  image_tag_mutability = "IMMUTABLE" 

  image_scanning_configuration {
    scan_on_push = true 
  }
}
