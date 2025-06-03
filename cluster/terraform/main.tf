provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.vpc_subnet_count)

  # Calculate subnet CIDRs dynamically based on the VPC CIDR
  vpc_cidr_prefix = split("/", var.vpc_cidr)[1]
  newbits         = 8 - (tonumber(local.vpc_cidr_prefix) - 16)

  # Generate private subnet CIDRs
  private_subnets = [
    for i in range(var.vpc_subnet_count) :
    cidrsubnet(var.vpc_cidr, local.newbits, i)
  ]

  # Generate public subnet CIDRs
  public_subnets = [
    for i in range(var.vpc_subnet_count) :
    cidrsubnet(var.vpc_cidr, local.newbits, i + var.vpc_subnet_count)
  ]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Enable OIDC provider for the cluster
  enable_irsa = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name           = var.node_group_name
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_capacity
      disk_size      = var.node_volume_size

      # Disable remote access to nodes
      remote_access = {
        ec2_ssh_key = null
      }

      labels = {
        role = "general-purpose"
      }
    }
  }

  # EKS Addons
  cluster_addons = var.cluster_addons

  # aws-auth configmap
  manage_aws_auth_configmap = true

  tags = var.tags
}