
#---------------------------------------------------------------
# External Secrets for Keycloak if enabled
#---------------------------------------------------------------
resource "aws_iam_policy" "external-secrets" {
  count = local.secret_count

  name_prefix = "cnoe-external-secrets-"
  description = "For use with External Secrets Controller for Keycloak"
  policy = jsonencode(
    {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource": [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:cnoe/keycloak/*"
        ]
      }
    ]
    }
  )
}

module "external_secrets_role_keycloak" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.14"
  count = local.secret_count

  role_name_prefix = "cnoe-external-secrets-"
  
  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks_oidc.arn
      namespace_service_accounts = ["keycloak:external-secret-keycloak"]
    }
  }
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets_role_attach" {
  count = local.dns_count

  role       = module.external_secrets_role_keycloak[0].iam_role_name
  policy_arn = aws_iam_policy.external-secrets[0].arn
}

# should use gitops really.
resource "kubernetes_manifest" "namespace_keycloak" {
  count = local.secret_count

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Namespace"
    "metadata" = {
      "name" = "keycloak"
    }
  }
}

resource "kubernetes_manifest" "serviceaccount_external_secret_keycloak" {
  count = local.secret_count
  depends_on = [
    kubernetes_manifest.namespace_keycloak,
    kubectl_manifest.application_argocd_external_secrets
  ]
  
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ServiceAccount"
    "metadata" = {
      "annotations" = {
        "eks.amazonaws.com/role-arn" = tostring(module.external_secrets_role_keycloak[0].iam_role_arn)
      }
      "name" = "external-secret-keycloak"
      "namespace" = "keycloak"
    }
  }
}

resource "aws_secretsmanager_secret" "keycloak_config" {
  count = local.secret_count

  description = "for use with cnoe keycloak installation"
  name = "cnoe/keycloak/config"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "keycloak_config" {
  count = local.secret_count

  secret_id     = aws_secretsmanager_secret.keycloak_config[0].id
  secret_string = jsonencode({
    KC_HOSTNAME = local.kc_domain_name
    KEYCLOAK_ADMIN_PASSWORD = random_password.keycloak_admin_password.result
    POSTGRES_PASSWORD = random_password.keycloak_postgres_password.result
    POSTGRES_DB = "keycloak"
    POSTGRES_USER = "keycloak"
    "user1-password" = random_password.keycloak_user_password.result
  })
}

resource "kubectl_manifest" "keycloak_secret_store" {
  depends_on = [
    kubectl_manifest.application_argocd_aws_load_balancer_controller,
    kubectl_manifest.application_argocd_external_secrets,
    kubernetes_manifest.serviceaccount_external_secret_keycloak
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/keycloak-secret-store.yaml", {
      REGION = local.region
    }
  )
}

#---------------------------------------------------------------
# Keycloak secrets if external secrets is not enabled
#---------------------------------------------------------------

resource "kubernetes_manifest" "secret_keycloak_keycloak_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    "metadata" = {
      "name" = "keycloak-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "KC_HOSTNAME" = "${base64encode(local.kc_domain_name)}"
      "KEYCLOAK_ADMIN_PASSWORD" = "${base64encode(random_password.keycloak_admin_password.result)}"
    }
  }
}

resource "kubernetes_manifest" "secret_keycloak_postgresql_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    "metadata" = {
      "name" = "postgresql-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "POSTGRES_DB" = "${base64encode("keycloak")}"
      "POSTGRES_PASSWORD" = "${base64encode(random_password.keycloak_postgres_password.result)}"
      "POSTGRES_USER" = "${base64encode("keycloak")}"
    }
  }
}

resource "kubernetes_manifest" "secret_keycloak_keycloak_user_config" {
  count = local.secret_count == 1 ? 0 : 1

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    "metadata" = {
      "name" = "keycloak-user-config"
      "namespace" = "keycloak"
    }
    "data" = {
      "user1-password" = "${base64encode(random_password.keycloak_user_password.result)}"
    }
  }
}

#---------------------------------------------------------------
# Keycloak passwords
#---------------------------------------------------------------

resource "random_password" "keycloak_admin_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

resource "random_password" "keycloak_user_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

resource "random_password" "keycloak_postgres_password" {
  length           = 48
  special          = false
  override_special = "!#?"
}

#---------------------------------------------------------------
# Keycloak installation
#---------------------------------------------------------------

resource "kubectl_manifest" "application_argocd_keycloak" {
  depends_on = [
    kubectl_manifest.keycloak_secret_store,
    kubectl_manifest.application_argocd_ingress_nginx
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/keycloak.yaml", {
      GITHUB_URL = local.repo_url
      PATH = "${local.secret_count == 1 ? "packages/keycloak/dev-external-secrets/" : "packages/keycloak/dev/"}"
    }
  )

  provisioner "local-exec" {
    command = "./install.sh '${random_password.keycloak_user_password.result}' '${random_password.keycloak_admin_password.result}'"

    working_dir = "${path.module}/scripts/keycloak"
    interpreter = ["/bin/bash", "-c"]
  }
  provisioner "local-exec" {
    when = destroy
    command = "./uninstall.sh"

    working_dir = "${path.module}/scripts/keycloak"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "ingress_keycloak" {
  depends_on = [
    kubectl_manifest.application_argocd_keycloak,
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/ingress-keycloak.yaml", {
      KEYCLOAK_DOMAIN_NAME = local.kc_domain_name
    }
  )
}
