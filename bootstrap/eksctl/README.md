# EKS Cluster eksctl Configuration

This directory contains eksctl configuration to create an EKS cluster. There is an equivalent Terraform configuration in the `bootstrap/terraform` directory.

## Prerequisites

- eksctl CLI tool
- AWS CLI configured with appropriate credentials
- kubectl (for interacting with the cluster after creation)

## Configuration

The main configuration is defined in `cluster-config.yaml`.

## Usage

```bash
# Create the cluster
eksctl create cluster -f cluster-config.yaml

# Delete the cluster
eksctl delete cluster -f cluster-config.yaml
```

## Features

- Creates an EKS cluster with version 1.32
- Sets up a managed node group with m5.large instances
- Configures autoscaling with min=3, max=6, desired=4 nodes
- Enables OIDC for the cluster
- Installs multiple EKS addons (aws-ebs-csi-driver, coredns, kube-proxy, vpc-cni)
- Creates a VPC with NAT gateway

## Connecting to the Cluster

After the cluster is created, you can configure kubectl to connect to it:

```bash
aws eks update-kubeconfig --region us-west-2 --name cnoe-ref-impl
```