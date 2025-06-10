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

# Delete idpbuilder local kind cluster instance
idpbuilder delete cluster --name localdev

# Get EKS kubeconfig
CLUSTER_NAME=$(yq '.cluster_name' config.yaml)
AWS_REGION=$(yq '.region' config.yaml)
KUBECONFIG_FILE=$(mktemp)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1

# Addons to be deleted
ADDONS=(
  backstage
  keycloak
  cert-manager
  external-dns
  external-secrets
  ingress-nginx
  aws-load-balancer-controller
)

# Delete all application sets except argocd
for app in "${ADDONS[@]}"; do
  echo "Deleting $app AppSet..."
  kubectl delete applicationsets.argoproj.io -n argocd $app --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
  # Wait for AppSet deletion to complete before moving to next AppSet
  while [ $(kubectl get applications.argoproj.io -n argocd -l addonName=$app --no-headers --kubeconfig $KUBECONFIG_FILE 2>/dev/null | wc -l) -ne 0 ]; do
    echo "Waiting for $app AppSet to be deleted..."
    sleep 10
  done
done

# Delete ArgoCD App
echo "Deleting argocd AppSet..."
kubectl delete applicationsets.argoproj.io -n argocd argocd --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1

# Wait for 2mins for ArgoCD to be deleted
echo "Waiting for argocd AppSet to be deleted..."
sleep 60

Remove PVCs for keycloak
echo "Deleting PVCs for keycloak..."
kubectl delete pvc -n keycloak data-keycloak-postgresql-0 --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1

# kubectl delete applications.argoproj.io argocd-hub -n argocd
# cd "${TF_DIR}"
# terraform destroy

# cd "${SETUP_DIR}/argocd/"
# ./uninstall.sh
# cd - 
