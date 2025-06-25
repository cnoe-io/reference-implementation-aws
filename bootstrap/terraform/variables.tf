variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cnoe-ref-impl"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

