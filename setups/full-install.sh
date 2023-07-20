#!/bin/bash
set -e -o pipefail

SETUP_DIR="$(git rev-parse --show-toplevel)/setups"

apps=("aws-load-balancer-controller" "ingress-nginx" "cert-manager" "external-dns" "keycloak" "argo-workflows" "backstage" "crossplane" "spark-operator")

cd "${SETUP_DIR}/argocd/"
./install.sh
cd -

for app in "${apps[@]}"; do
  set +e
  exists=$(kubectl get -f "${SETUP_DIR}/${app}/argo-app.yaml")
  if [[ ! -z "${exists}" ]]; then
    echo -e "ArgoCD Application for ${GREEN}${app}${NC} already exists. Will not re-install."
    continue
  fi
  set -e
  echo -e "${GREEN}Installing ${app}${NC}"
  cd "${SETUP_DIR}/${app}/"
  ./install.sh
  cd -
  echo "------------\n"
done
