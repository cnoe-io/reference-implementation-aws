#---------------------------------------------------------------
# Setups to run Data on EKS demo
#---------------------------------------------------------------
module "data_on_eks_runner_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
  role_name_prefix = "cnoe-external-dns"
  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["data-on-eks:data-on-eks"]
    }
  }
  tags = var.tags
}

resource "kubernetes_manifest" "namespace_data_on_eks" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Namespace"
    "metadata" = {
      "name" = "data-on-eks"
    }
  }
}

resource "kubernetes_manifest" "serviceaccount_data_on_eks" {
  depends_on = [
    kubernetes_manifest.namespace_data_on_eks
  ]
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ServiceAccount"
    "metadata" = {
      "annotations" = {
        "eks.amazonaws.com/role-arn" = tostring(module.data_on_eks_runner_role.iam_role_arn)
      }
      "labels" = {
        "app" = "data-on-eks"
      }
      "name" = "data-on-eks"
      "namespace" = "data-on-eks"
    }
  }
}


#---------------------------------------------------------------
# Argo Workflows
#---------------------------------------------------------------

resource "kubernetes_manifest" "namespace_argo_workflows" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Namespace"
    "metadata" = {
      "name" = "argo"
    }
  }
}

resource "terraform_data" "argo_workflows_keycloak_setup" {
  depends_on = [
    kubectl_manifest.application_argocd_keycloak,
    kubernetes_manifest.namespace_argo_workflows
  ]

  provisioner "local-exec" {
    command = "./install.sh"

    working_dir = "${path.module}/scripts/argo-workflows"
    environment = {
      "ARGO_WORKFLOWS_REDIRECT_URL" = "${local.argo_redirect_url}"
    }
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy
    
    command = "./uninstall.sh"
    working_dir = "${path.module}/scripts/argo-workflows"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "application_argocd_argo_workflows" {
  depends_on = [
    terraform_data.argo_workflows_keycloak_setup
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/argo-workflows.yaml", {
      GITHUB_URL = local.repo_url
      KEYCLOAK_CNOE_URL = local.kc_cnoe_url
      ARGO_REDIRECT_URL = local.argo_redirect_url
    }
  )
}

resource "kubectl_manifest" "application_argocd_argo_workflows_templates" {
  depends_on = [
    terraform_data.argo_workflows_keycloak_setup
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/argo-workflows-templates.yaml", {
      GITHUB_URL = local.repo_url
    }
  )
}

resource "kubectl_manifest" "application_argocd_argo_workflows_sso_config" {
  depends_on = [
    terraform_data.argo_workflows_keycloak_setup
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/argo-workflows-sso-config.yaml", {
      GITHUB_URL = local.repo_url
    }
  )
}

resource "kubectl_manifest" "ingress_argo_workflows" {
  depends_on = [
    kubectl_manifest.application_argocd_argo_workflows,
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/ingress-argo-workflows.yaml", {
      ARGO_WORKFLOWS_DOMAIN_NAME = local.argo_domain_name
    }
  )
}
