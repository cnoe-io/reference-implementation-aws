# EKS Cluster Setup with Terraform

This directory contains Terraform configuration to create an EKS cluster with pod identity associations for various AWS services. The configuration supports both standard EKS clusters and EKS Auto Mode.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed

## Create Cluster
Run the following command and follow the instructions:

```bash
export REPO_ROOT=$(git rev-parse --show-toplevel)
$REPO_ROOT/scripts/create-cluster.sh
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

### Compute Resources

#### Auto Mode (when `auto_mode = true`)
- EKS Auto Mode enabled with general-purpose node pools
- Automatic compute resource management

#### Standard Mode (when `auto_mode = false`)
- Managed node group with 3-6 m5.large instances
- Desired capacity: 4 nodes
- 100GB EBS volumes per node
- Node IAM role with required policies

### EKS Addons

#### Auto Mode
- All addons managed automatically by EKS Auto Mode
- No explicit addon configuration required

#### Standard Mode
- eks-pod-identity-agent
- aws-ebs-csi-driver with EBS CSI controller policies
- vpc-cni
- coredns
- kube-proxy

### Pod Identity Associations

#### Always Created (Both Modes)
- **crossplane-system/provider-aws**: AdministratorAccess + permissions boundary
- **external-secrets/external-secrets**: Secrets Manager access policies
- **external-dns/external-dns**: Route 53 DNS management policies

#### Standard Mode Only
- **kube-system/aws-load-balancer-controller**: AWS Load Balancer Controller policies
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
export REPO_ROOT=$(git rev-parse --show-toplevel)
export export TF_VAR_auto_mode="true" # set this to "false" if using non-auto mode
terraform -chdir=$REPO_ROOT/cluster/terraform destroy
```

This will clean up:
- EKS cluster
- Managed node groups (if using standard mode)
- Pod identity associations
- IAM roles and policies created by Terraform
- VPC and networking resources
- EKS addons
- Crossplane permissions boundary policy

> [!NOTE]
> Manual cleanup may be required for any resources created outside of Terraform or if the deletion process encounters errors.