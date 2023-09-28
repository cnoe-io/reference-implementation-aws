
locals {
  repo_url = trimsuffix(var.repo_url, "/")
  region = var.region
  tags = var.tags
  cluster_name    = var.cluster_name
  hosted_zone_id = var.hosted_zone_id
  dns_count = var.enable_dns_management ? 1 : 0
  secret_count = var.enable_external_secret ? 1 : 0

  domain_name = var.enable_dns_management ? "${trimsuffix(data.aws_route53_zone.selected[0].name, ".")}" : "${var.domain_name}"
  kc_domain_name = "keycloak.${local.domain_name}"
  kc_cnoe_url = "https://${local.kc_domain_name}/realms/cnoe"
  argo_domain_name = "argo.${local.domain_name}"
  argo_redirect_url = "https://${local.argo_domain_name}/oauth2/callback"
  argocd_domain_name = "argocd.${local.domain_name}"
  backstage_domain_name = "backstage.${local.domain_name}"
}


provider "aws" {
  region = local.region
  default_tags {
    tags = local.tags
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
