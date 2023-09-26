data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks_oidc" {
  url = data.aws_eks_cluster.target.identity[0].oidc[0].issuer
}

data "aws_route53_zone" "selected" {
  count = local.dns_count
  zone_id = local.hosted_zone_id
}

data "aws_caller_identity" "current" {}
