module "crossplane_aws_provider_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_name_prefix = "cnoe-crossplane-provider-aws"
  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  assume_role_condition_test = "StringLike"
  oidc_providers = {
    main = {
      provider_arn  = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["crossplane-system:provider-aws*"]
    }
  }
  tags = var.tags
}

resource "kubectl_manifest" "application_argocd_crossplane" {
  yaml_body = templatefile("${path.module}/templates/argocd-apps/crossplane.yaml", {
     GITHUB_URL = local.repo_url
    }
  )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/crossplane --timeout=300s &&  kubectl wait --for=jsonpath=.status.sync.status=Synced --timeout=300s -n argocd application/crossplane"

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command = "./uninstall.sh"
    working_dir = "${path.module}/scripts/crossplane"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "crossplane_provider_controller_config" {
  depends_on = [ 
    kubectl_manifest.application_argocd_crossplane, 
  ]
  yaml_body = templatefile("${path.module}/templates/manifests/crossplane-aws-controller-config.yaml", {
     ROLE_ARN = module.crossplane_aws_provider_role.iam_role_arn
    }
  )
}

resource "kubectl_manifest" "application_argocd_crossplane_provider" {
  depends_on = [ 
    kubectl_manifest.application_argocd_crossplane, 
  ]
  yaml_body = templatefile("${path.module}/templates/argocd-apps/crossplane-provider.yaml", {
     GITHUB_URL = local.repo_url
    }
  )
}

resource "kubectl_manifest" "application_argocd_crossplane_compositions" {
  depends_on = [ 
    kubectl_manifest.application_argocd_crossplane, 
  ]
  yaml_body = templatefile("${path.module}/templates/argocd-apps/crossplane-compositions.yaml", {
     GITHUB_URL = local.repo_url
    }
  )
}
