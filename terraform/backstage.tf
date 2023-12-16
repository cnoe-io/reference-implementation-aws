resource "random_password" "backstage_postgres_password" {
  length           = 48
  special          = true
  override_special = "!#"
}

resource "kubernetes_manifest" "namespace_backstage" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Namespace"
    "metadata" = {
      "name" = "backstage"
    }
  }
}

resource "kubernetes_manifest" "secret_backstage_postgresql_config" {
  depends_on = [
    kubernetes_manifest.namespace_backstage
  ]

  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    "metadata" = {
      "name" = "postgresql-config"
      "namespace" = "backstage"
    }
    "data" = {
      "POSTGRES_DB" = "${base64encode("backstage")}"
      "POSTGRES_PASSWORD" = "${base64encode(random_password.backstage_postgres_password.result)}"
      "POSTGRES_USER" = "${base64encode("backstage")}"
    }
  }
}

resource "terraform_data" "backstage_keycloak_setup" {
  depends_on = [
    kubectl_manifest.application_argocd_keycloak,
    kubernetes_manifest.namespace_backstage
  ]

  provisioner "local-exec" {
    command = "./install.sh ${random_password.backstage_postgres_password.result} ${local.backstage_domain_name} ${local.kc_domain_name} ${local.argo_domain_name}"

    working_dir = "${path.module}/scripts/backstage"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command = "./uninstall.sh"

    working_dir = "${path.module}/scripts/backstage"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "kubectl_manifest" "application_argocd_backstage" {
  depends_on = [
    terraform_data.backstage_keycloak_setup
  ]

  yaml_body = templatefile("${path.module}/templates/argocd-apps/backstage.yaml", {
      GITHUB_URL = local.repo_url
    }
  )
}

resource "kubectl_manifest" "ingress_backstage" {
  depends_on = [
    kubectl_manifest.application_argocd_backstage,
  ]

  yaml_body = templatefile("${path.module}/templates/manifests/ingress-backstage.yaml", {
      BACKSTAGE_DOMAIN_NAME = local.backstage_domain_name
    }
  )
}
