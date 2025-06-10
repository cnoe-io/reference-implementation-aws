#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
# SETUP_DIR="${REPO_ROOT}/setups"
# TF_DIR="${REPO_ROOT}/terraform"
source ${REPO_ROOT}/scripts/utils.sh

# cd ${SETUP_DIR}

echo -e "${PURPLE}\nTargets:${NC}"
echo "Kubernetes cluster: $(kubectl config current-context)"
echo "AWS profile (if set): ${AWS_PROFILE}"
echo "AWS account number: $(aws sts get-caller-identity --query "Account" --output text)"

echo -e "${RED}\nAre you sure you want to continue?${NC}"
read -p '(yes/no): ' response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo 'exiting.'
  exit 0
fi

CLUSTER_NAME=$(yq '.cluster_name' config.yaml)
AWS_REGION=$(yq '.region' config.yaml)

ADDONS=(
  keycloak
  cert-manager
  external-dns
  external-secrets
  ingress-nginx
  aws-load-balancer-controller
)
# KUBECONFIG_FILE=$(mktemp)
# aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE
# KUBECONFIG=$(kubectl config --kubeconfig $KUBECONFIG_FILE view --raw -o json)
# SERVER_URL=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster.server')
# CA_DATA=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster."certificate-authority-data"')

# Delete all application sets except argocd
for app in "${ADDONS[@]}"; do 
  kubectl delete applicationsets.argoproj.io -n argocd $app
done

# Patch ArgoCD AppSet to remove finalizer and Delete it
kubectl patch applicationsets.argoproj.io -n argocd argocd --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl delete applicationsets.argoproj.io -n argocd argocd

# Delete ArgoCD App
kubectl delete applicationsets.argoproj.io -n argocd argocd

# Wait for 3mins for ArgoCD to be deleted
sleep 600

# Patch ArgoCD App to remove finalizer for completing deletion of ArgoCD App.
kubectl patch applications.argoproj.io -n argocd argocd --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'

# kubectl delete applications.argoproj.io argocd-hub -n argocd
# cd "${TF_DIR}"
# terraform destroy

# cd "${SETUP_DIR}/argocd/"
# ./uninstall.sh
# cd - 
