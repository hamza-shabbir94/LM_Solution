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

  # Predictable naming instead of the module's default (a name prefix
  # plus a random suffix, used by default to avoid IAM name-reuse
  # collisions on rapid recreate). Deterministic names are easier to
  # reference/read in the console and in IAM policy ARNs elsewhere.
  iam_role_name            = "${var.environment}-api-service-cluster-role"
  iam_role_use_name_prefix = false

  # Without this, NOBODY has Kubernetes RBAC access after creation --
  # not even the IAM identity that ran `terraform apply`. Required in
  # module v20+ since the old aws-auth ConfigMap behavior (creator gets
  # automatic admin) was replaced with explicit EKS access entries.
  # This grants the applying identity a ClusterAdmin access entry.
  enable_cluster_creator_admin_permissions = true

  # Portable across AWS accounts: empty by default (see
  # additional_access_entries in variables.tf). Real per-person entries
  # are supplied locally via a gitignored .tfvars file, never hardcoded
  # here, since an account-specific IAM ARN means nothing in anyone
  # else's AWS account.
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

  # Enables the OIDC provider needed for IRSA (IAM Roles for Service
  # Accounts). Not consumed by anything in this module right now (a
  # plain `type: LoadBalancer` Service needs no extra IAM role), but
  # it's the prerequisite any future pod-level AWS integration (e.g.
  # the AWS Load Balancer Controller, External Secrets, etc.) would
  # need -- see SOLUTION.md "if I had more time".
  enable_irsa = true

  # Explicit rather than relying on the module's implicit defaults
  # (public=true, private=true). Private access is turned OFF here: the
  # VPC already has a NAT gateway, so worker nodes reach the control
  # plane via the public endpoint over that outbound path regardless,
  # and disabling private access removes a real footgun -- with both
  # enabled, DNS for the cluster endpoint can resolve to a private IP
  # depending on the resolver/VPC association of whoever's connecting,
  # which silently breaks kubectl for anyone outside this VPC (exactly
  # what happened testing this tonight). Public access stays on, scoped
  # by cluster_endpoint_public_access_cidrs above, no VPC peering or
  # hand-written security group needed -- EKS manages the control
  # plane's security group automatically from these three settings.
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
