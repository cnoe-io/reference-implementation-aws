# EKS Cluster Setup with eksctl

This directory contains the configuration to create an EKS cluster with pod identity associations for various AWS services.

## Prerequisites

- AWS CLI configured with appropriate permissions
- eksctl installed
- kubectl installed

## Environment Variables

Set the following environment variables before creating the cluster:

```bash
export CLUSTER_NAME="cnoe-ref-impl"
export REGION="us-west-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

## Create Cluster

```bash
cat bootstrap/eksctl/cluster-config.yaml | envsubst | eksctl create cluster -f -
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

### Managed Node Group
- Managed node group with 3-6 m5.large instances
- Desired capacity: 4 nodes
- 100GB EBS volumes per node
- Node IAM role with required policies

### EKS Addons
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

To delete the cluster and all associated resources:

```bash
eksctl delete cluster --name $CLUSTER_NAME --region $REGION
```

This will automatically clean up:
- EKS cluster
- Managed node groups
- Pod identity associations
- IAM roles and policies created by eksctl
- VPC and networking resources (if created by eksctl)
- EKS addons

**Note**: Manual cleanup may be required for any resources created outside of eksctl or if the deletion process encounters errors.