variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cnoe-ref-impl"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_subnet_count" {
  description = "Number of subnets to create in the VPC (minimum 2, maximum based on CIDR block)"
  type        = number
  default     = 3
}

variable "cluster_addons" {
  description = "Map of EKS cluster addons to enable with their versions"
  type        = map(map(string))
  default = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
}

variable "node_group_name" {
  description = "Name of the EKS managed node group"
  type        = string
  default     = "managed-ng-1"
}

variable "node_instance_type" {
  description = "Instance type for the EKS managed node group"
  type        = string
  default     = "m5.large"
}

variable "node_min_size" {
  description = "Minimum size of the EKS managed node group"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum size of the EKS managed node group"
  type        = number
  default     = 6
}

variable "node_desired_capacity" {
  description = "Desired capacity of the EKS managed node group"
  type        = number
  default     = 4
}

variable "node_volume_size" {
  description = "Volume size for the EKS managed node group"
  type        = number
  default     = 100
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}