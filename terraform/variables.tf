variable "repo_url" {
  description = "Repository URL where application definitions are stored"
  default     = "https://github.com/manabuOrg/ref-impl"
  type        = string
}

variable "tags" {
    description = "Tags to apply to AWS resources"
    default = {
        env = "dev"
        project = "cnoe"
    }
    type = map(string)
}

variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS Cluster name"
  default     = "cnoe-ref-impl"
  type        = string
}

variable "hosted_zone_id" {
  description = "If using external DNS, specify the Route53 hosted zone ID. Required if enable_dns_management is set to true."
  default     = "Z0202147IFM0KVTW2P35"
  type        = string
}

variable "domain_name" {
  description = "if external DNS is not used, this value must be provided."
  default     = "svc.cluster.local"
  type        = string
}

variable "organization_url" {
  description = "github organization url"
  default     = "https://github.com/cnoe-io"
  type        = string
}

variable "enable_dns_management" {
  description = "Do you want to use external dns to manage dns records in Route53?"
  default     = true
  type        = bool
}

variable "enable_external_secret" {
  description = "Do you want to use external secret to manage dns records in Route53?"
  default     = true
  type        = bool
}
