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


apps=("aws-load-balancer-controller" "ingress-nginx" "cert-manager" "external-dns" "keycloak" "argo-workflows" "backstage" "crossplane" "spark-operator")

filter=("external-dns")

apps_to_install=()
for i in "${apps[@]}"; do
    skip=
    for j in "${filter[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || apps_to_install+=("$i")
done

# apps_to_install=($(echo ${apps[@]} ${filter[@]} | tr ' ' '\n' | sort | uniq -u))



for app in "${apps_to_install[@]}"; do
  echo ${app}
done