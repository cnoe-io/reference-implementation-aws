# EKS Cluster Setup with eksctl

This directory contains the configuration to create an EKS cluster with pod identity associations for various AWS services.

## Prerequisites

- AWS CLI configured with appropriate permissions
- eksctl installed

## Create Cluster
Run the following command and follow the instructions:

```bash
export REPO_ROOT=$(git rev-parse --show-toplevel)
$REPO_ROOT/scripts/create-cluster.sh
```

## AWS Resources Created

The cluster creation will provision the following AWS resources:

### EKS Cluster
- EKS cluster with Kubernetes version 1.33
- VPC with CIDR 10.0.0.0/16
- Single NAT Gateway
- Public and private subnets across availability zones
- EKS cluster security groups
- OIDC identity provider

### Managed Node Group _(For Non-Auto Mode cluster)_
- Managed node group with 3-6 m5.large instances
- Desired capacity: 4 nodes
- 100GB EBS volumes per node
- Node IAM role with required policies

### EKS Addons _(For Non-Auto Mode cluster)_
- eks-pod-identity-agent
- aws-ebs-csi-driver with EBS CSI controller policies
- vpc-cni (default)
- coredns (default)
- kube-proxy (default)

### Pod Identity Associations
- **crossplane-system/provider-aws**: AdministratorAccess + permissions boundary
- **external-secrets/external-secrets**: Secrets Manager access policies
- **kube-system/aws-load-balancer-controller**: AWS Load Balancer Controller policies
- **external-dns/external-dns**: Route 53 DNS management policies

### IAM Resources
- IAM roles for pod identity associations
- IAM policies for service-specific permissions
- OIDC identity provider for the cluster

## Cleanup

> [!CAUTION]
> Ensure all workloads are removed from the cluster before destroying to avoid orphaned resources.

To delete the cluster and all associated resources:

```bash
# Delete the EKS cluster
export $CLUSTER_NAME="cnoe-ref-impl"
export AWS_REGION="us-west-2"
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

# Delete the permissions boundary policy
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/crossplane-permissions-boundary
```

This will automatically clean up the following:
- EKS cluster
- Managed node groups
- Pod identity associations
- IAM roles and policies created by eksctl
- VPC and networking resources (if created by eksctl)
- EKS addons
- Crossplane permissions boundary policy

> [!NOTE]
> Manual cleanup may be required for any resources created outside of eksctl or if the deletion process encounters errors.
