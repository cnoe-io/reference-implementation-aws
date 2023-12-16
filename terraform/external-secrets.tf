resource "kubectl_manifest" "application_argocd_external_secrets" {
  yaml_body = templatefile("${path.module}/templates/argocd-apps/external-secrets.yaml", {
      GITHUB_URL = local.repo_url
    }
    )

  provisioner "local-exec" {
    command = "kubectl wait --for=jsonpath=.status.health.status=Healthy --timeout=300s -n argocd application/external-secrets"

    interpreter = ["/bin/bash", "-c"]
  }
}
