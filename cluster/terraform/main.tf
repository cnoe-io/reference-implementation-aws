provider "aws" {
  region = var.region
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

data "template_file" "crossplane_boundary_policy" {
  template = file("${path.module}/../iam-policies/crossplane-permissions-boundry.json")
  vars = {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
  }
}

data "template_file" "external_secret_policy" {
  template = file("${path.module}/../iam-policies/external-secrets.json")
  vars = {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
  }
}
locals {
  name   = var.cluster_name
  region = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    githubRepo = "github.com/cnoe-io/reference-implementation-aws"
    env = "dev"
    project = "cnoe"
  }
}

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name                   = local.name
  cluster_version                = "1.33"
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  # EKS Auto Mode configuration
  # When enabled, EKS automatically manages compute resources and core addons
  # This eliminates the need for managed node groups and manual addon management
  cluster_compute_config = var.auto_mode ? {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  } : null

  # Only create managed node groups when not using Auto Mode
  # Auto Mode handles compute resources automatically
  eks_managed_node_groups = var.auto_mode ? {} : {
    initial = {
      instance_types = ["m5.large"]
      
      min_size     = 3
      max_size     = 6
      desired_size = 4

      disk_size = 100
      
      labels = {
        pool = "system"
      }
    }
  }

  # Conditional cluster addons based on Auto Mode
  # Auto Mode automatically manages: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver, AWS Load Balancer Controller, eks-pod-identity-agent
  cluster_addons = var.auto_mode ? {
    # Auto Mode manages all addons automatically - no explicit addon configuration needed
  } : {
    # Standard mode requires all addons to be explicitly managed
    coredns = {}
    eks-pod-identity-agent = {}
    kube-proxy = {}
    vpc-cni = {}
    aws-ebs-csi-driver = {}
  }
  
  tags = local.tags
}


################################################################################
# IAM Policies
################################################################################

resource "aws_iam_policy" "crossplane_boundary" {
  name   = "crossplane-permissions-boundary"
  policy = data.template_file.crossplane_boundary_policy.rendered

  tags = local.tags
}

################################################################################
# Pod Identity
################################################################################

# AWS Load Balancer Controller - Only needed when not using Auto Mode
module "aws_load_balancer_controller_pod_identity" {
  count   = var.auto_mode ? 0 : 1
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name = "aws_load_balancer_controller"
  attach_aws_lb_controller_policy = true
  associations = {
    external_secrets = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = local.tags
}

# External DNS - Required for both Auto Mode and standard mode
module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name = "external-dns"
  attach_external_dns_policy = true
  external_dns_hosted_zone_arns = [ "*" ]
  associations = {
    external_secrets = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }
  tags = local.tags
}

# EBS CSI Driver - Only needed when not using Auto Mode
module "ebs_csi_driver_pod_identity" {
  count   = var.auto_mode ? 0 : 1
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name = "ebs-csi-driver"
  attach_aws_ebs_csi_policy = true
  associations = {
    external_secrets = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
  tags = local.tags
}

# Crossplane - Required for both Auto Mode and standard mode
module "crossplane_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name = "crossplane-provider-aws"

  additional_policy_arns   = {
    admin = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
  permissions_boundary_arn = aws_iam_policy.crossplane_boundary.arn

  associations = {
    crossplane = {
      cluster_name    = module.eks.cluster_name
      namespace       = "crossplane-system"
      service_account = "provider-aws"
    }
  }

  tags = local.tags
}

# External Secrets - Required for both Auto Mode and standard mode
module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.0"

  name = "external-secrets"
  attach_custom_policy = true
  override_policy_documents = [data.template_file.external_secret_policy.rendered]
  associations = {
    external_secrets = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }

  tags = local.tags
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}