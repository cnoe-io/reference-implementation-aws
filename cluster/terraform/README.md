# EKS Cluster Setup with Terraform

This directory contains Terraform configuration to create an EKS cluster with pod identity associations for various AWS services.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed

## Environment Variables

Set the following environment variables before creating the cluster:

```bash
export TF_VAR_cluster_name="cnoe-ref-impl"
export TF_VAR_region="us-west-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

## Deploy

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

## Configure kubectl

After deployment, configure kubectl to connect to your cluster:

```bash
aws eks --region $TF_VAR_region update-kubeconfig --name $TF_VAR_cluster_name
```

## AWS Resources Created

The Terraform configuration will provision the following AWS resources:

### EKS Cluster
- EKS cluster with Kubernetes version 1.33
- VPC with CIDR 10.0.0.0/16
- Single NAT Gateway
- Public and private subnets across 3 availability zones
- EKS cluster security groups
- OIDC identity provider

### Managed Node Group
- Managed node group with 3-6 m5.large instances
- Desired capacity: 4 nodes
- 100GB EBS volumes per node
- Node IAM role with required policies

### EKS Addons
- eks-pod-identity-agent
- aws-ebs-csi-driver with EBS CSI controller policies
- vpc-cni
- coredns
- kube-proxy

### Pod Identity Associations
- **crossplane-system/provider-aws**: AdministratorAccess + permissions boundary
- **external-secrets/external-secrets**: Secrets Manager access policies
- **kube-system/aws-load-balancer-controller**: AWS Load Balancer Controller policies
- **external-dns/external-dns**: Route 53 DNS management policies
- **kube-system/ebs-csi-controller-sa**: EBS CSI driver policies

### IAM Resources
- IAM roles for pod identity associations
- IAM policies for service-specific permissions
- OIDC identity provider for the cluster
- Crossplane permissions boundary policy

## Cleanup

> [!CAUTION]
> Ensure all workloads are removed from the cluster before destroying to avoid orphaned resources.

To delete the cluster and all associated resources:

```bash
# Destroy the Terraform-managed resources
terraform destroy
```

This will clean up:
- EKS cluster
- Managed node groups
- Pod identity associations
- IAM roles and policies created by Terraform
- VPC and networking resources
- EKS addons
- Crossplane permissions boundary policy


> [!NOTE]
> Manual cleanup may be required for any resources created outside of eksctl or if the deletion process encounters errors.