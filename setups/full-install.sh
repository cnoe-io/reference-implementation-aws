#!/bin/bash
set -e -o pipefail

SETUP_DIR="$(git rev-parse --show-toplevel)/setups"

apps=("argocd" "aws-load-balancer-controller" "ingress-nginx" "cert-manager" "external-dns" "keycloak" "argo-workflows" "backstage" "crossplane" "spark-operator")

for app in "${apps[@]}"; do
  exists=$(kubectl get -f "${SETUP_DIR}/${app}/argo-app.yaml")
  if [[ ! -z "${exists}" ]]; then
    echo -e "ArgoCD Application for ${app} already exists. Will not re-install."
    continue
  fi
  echo "${GREEN}Installing ${app}${NC}"
  cd "${SETUP_DIR}/${app}/"
  ./install.sh
  cd -
done
