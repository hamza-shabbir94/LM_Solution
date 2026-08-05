# This Terraform configuration file sets up an Amazon EKS (Elastic Kubernetes Service) cluster along with a VPC (Virtual Private Cloud) and associated resources. 
# It uses the Terraform AWS provider to create and manage the necessary AWS infrastructure for running a Kubernetes cluster. 
# The configuration includes modules for creating a VPC, subnets, and an EKS cluster with managed node groups, as well as IAM roles and policies for access control.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------
# VPC and subnets for the EKS cluster
# ------------------------------------------------------------------
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
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.environment}-api-service" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
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

  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # Same predictable-naming reasoning as the cluster role above.
      iam_role_name            = "${var.environment}-api-service-node-role"
      iam_role_use_name_prefix = false

      
      subnet_ids = module.vpc.private_subnets
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}



