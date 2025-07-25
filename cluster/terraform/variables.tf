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

variable "auto_mode" {
  description = "Enable EKS Auto Mode. When enabled, EKS automatically manages compute resources and many addons."
  type        = bool
  default     = false
}

