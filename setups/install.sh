#!/bin/bash
set -e -o pipefail

source ./utils.sh

full_apps=("aws-load-balancer-controller" "ingress-nginx" "cert-manager" "external-dns" "keycloak" "argo-workflows" "backstage" "crossplane" "spark-operator")

apps_to_install=()

filter_apps() {
  for i in "${full_apps[@]}"; do
    skip=
    for j in "${filtered_apps[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || apps_to_install+=("$i")
  done
}

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}/setups
env_file=${REPO_ROOT}/setups/config

while IFS='=' read -r key value; do
  [[ $key == \#* ]] && continue
  export "$key"="$value"
done < $env_file

if [[ ! -z "${GITHUB_URL}" ]]; then
    export GITHUB_URL=$(strip_trailing_slash "${GITHUB_URL}")
fi

if [[ ! -z "${DOMAIN_NAME}" ]]; then
    export DOMAIN_NAME=$(get_cleaned_domain_name "${DOMAIN_NAME}")
fi

env_vars=("GITHUB_URL" "DOMAIN_NAME" "BACKSTAGE_SSO_ENABLED" "ARGO_SSO_ENABLED" "CLUSTER_NAME" "REGION" "MANAGED_DNS" "MANAGED_CERT" "HOSTEDZONE_ID")

echo -e "${GREEN}Installing with the following options: ${NC}"
for env_var in "${env_vars[@]}"; do
  echo -e "${env_var}: ${!env_var}"
done

echo -e "${PURPLE}\nTargets:${NC}"
echo "Kubernetes cluster: $(kubectl config current-context)"
echo "AWS profile (if set): ${AWS_PROFILE}"
echo "AWS account number: $(aws sts get-caller-identity --query "Account" --output text)"

echo -e "${GREEN}\nAre you sure you want to continue?${NC}"
read -p '(yes/no): ' response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo 'exiting.'
  exit 0
fi


if [[ "${MANAGED_CERT}" == "true" && "${MANAGED_DNS}" == "true" ]]; then
  install_apps "${full_apps[@]}"
  exit
fi

filtered_apps=()

if [[ "${MANAGED_DNS}" == "false" ]];
then
  filtered_apps+=("external-dns")
fi

if [[ "${MANAGED_CERT}" == "false" ]];
then
  filtered_apps+=("cert-manager")
fi

filter_apps
install_apps "${apps_to_install[@]}"
