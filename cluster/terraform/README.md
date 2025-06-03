# EKS Cluster Terraform Configuration

This directory contains Terraform configuration to create an EKS cluster equivalent to the one defined in `bootstrap/eksctl/cluster-config.yaml`.

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials
- kubectl (optional, for interacting with the cluster after creation)

## Configuration

The main configuration parameters are defined in `variables.tf`. You can override these by creating a `terraform.tfvars` file or by passing variables on the command line.

### Configuring EKS Addons

You can specify which EKS addons to install and their versions in your `terraform.tfvars` file:

```hcl
# Use the most recent version of an addon
cluster_addons = {
  aws-ebs-csi-driver = {
    most_recent = true
  }
}

# Or specify exact versions
cluster_addons = {
  aws-ebs-csi-driver = {
    addon_version = "v1.43.0-eksbuild.1"
  }
  coredns = {
    addon_version = "v1.10.1-eksbuild.1"
  }
}
```

## Usage

```bash
# Initialize Terraform
terraform init

# Preview the changes
terraform plan

# Apply the changes
terraform apply

# To destroy the resources
terraform destroy
```

## Features

- Creates an EKS cluster with version 1.32
- Sets up a managed node group with m5.large instances
- Configures autoscaling with min=3, max=6, desired=4 nodes
- Enables OIDC for the cluster
- Installs multiple EKS addons (aws-ebs-csi-driver, coredns, kube-proxy, vpc-cni)
- Creates a VPC with public and private subnets across 3 AZs
- Supports dynamic VPC CIDR and subnet configuration
- Allows customization of EKS addons and versions

## Outputs

After applying the configuration, Terraform will output several useful values including:

- Cluster endpoint
- Cluster name
- VPC ID
- Subnet IDs
- Region

## Connecting to the Cluster

After the cluster is created, you can configure kubectl to connect to it:

```bash
aws eks update-kubeconfig --region us-west-2 --name cnoe-ref-impl
```