module "aws_load_balancer_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "cnoe-aws-load-balancer-controller-"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["aws-load-balancer-controller:aws-load-balancer-controller"]
    }
  }
  tags = var.tags
}

resource "kubectl_manifest" "application_argocd_aws_load_balancer_controller" {
  depends_on = [ module.aws_load_balancer_role ]
  yaml_body = templatefile("${path.module}/templates/argocd-apps/aws-load-balancer.yaml", {
     CLUSTER_NAME = local.cluster_name
     ROLE_ARN = module.aws_load_balancer_role.iam_role_arn
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/aws-load-balancer-controller"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command = "kubectl wait --for=delete svc ingress-nginx-controller -n ingress-nginx --timeout=300s"

    interpreter = ["/bin/bash", "-c"]
  }
}
