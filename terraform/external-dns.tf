
resource "aws_iam_policy" "external-dns" {
  count = local.dns_count

  name_prefix = "cnoe-external-dns-"
  description = "For use with External DNS Controller"
  policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Effect": "Allow",
            "Action": [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets",
            "route53:ListTagsForResource"
            ],
            "Resource": [
            "arn:aws:route53:::hostedzone/${local.hosted_zone_id}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
            "route53:ListHostedZones"
            ],
            "Resource": [
            "*"
            ]
        }
        ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "external_dns_role_attach" {
  count = local.dns_count

  role       = module.external_dns_role[0].iam_role_name
  policy_arn = aws_iam_policy.external-dns[0].arn
}

module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"
  count = local.dns_count

  role_name_prefix = "cnoe-external-dns"
  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
  tags = var.tags
}

resource "kubectl_manifest" "application_argocd_external_dns" {
  yaml_body = templatefile("${path.module}/templates/argocd-apps/external-dns.yaml", {
      GITHUB_URL = local.repo_url
      ROLE_ARN = module.external_dns_role[0].iam_role_arn
      DOMAIN_NAME = data.aws_route53_zone.selected[0].name
    }
    )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy --timeout=300s -n argocd application/external-dns"

    interpreter = ["/bin/bash", "-c"]
  }
}
