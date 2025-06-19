#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
source ${REPO_ROOT}/scripts/utils.sh

CLUSTER_NAME=$(yq '.cluster_name' config.yaml)
AWS_REGION=$(yq '.region' config.yaml)

# Header
echo -e "${BOLD}${RED}🗑️ ========================================== 🗑️${NC}"
echo -e "${BOLD}${RED}🧹      CNOE AWS Reference Implementation     🧹${NC}"
echo -e "${BOLD}${RED}🗑️ ========================================== 🗑️${NC}\n"

echo -e "${BOLD}${PURPLE}🎯 Targets:${NC}"
echo -e "${CYAN}🔶 Kubernetes cluster:${NC} $CLUSTER_NAME in ${BOLD}$AWS_REGION${NC}"
echo -e "${CYAN}🔶 AWS profile (if set):${NC} ${AWS_PROFILE:-None}"
echo -e "${CYAN}🔶 AWS account number:${NC} $(aws sts get-caller-identity --query "Account" --output text)"

echo -e "\n${BOLD}${RED}⚠️  WARNING: This will remove all deployed resources!${NC}"
echo -e "${BOLD}${RED}❓ Are you sure you want to continue?${NC}"
read -p '(yes/no): ' response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo -e "${YELLOW}⚠️  Uninstallation cancelled.${NC}"
  exit 0
fi

echo -e "\n${BOLD}${BLUE}🚀 Starting uninstallation process...${NC}"

# Delete idpbuilder local kind cluster instance
echo -e "${CYAN}🔄 Deleting idpbuilder local kind cluster instance...${NC}"
idpbuilder delete cluster --name localdev > /dev/null 2>&1

# Get EKS kubeconfig
echo -e "${PURPLE}🔑 Generating temporary kubeconfig for cluster ${BOLD}${CLUSTER_NAME}${NC}...${NC}"
KUBECONFIG_FILE=$(mktemp)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1

# Addons to be deleted
ADDONS=(
  crossplane
  argo-workflows
  backstage
  keycloak
  cert-manager
  external-dns
  external-secrets
  ingress-nginx
  aws-load-balancer-controller
)

# Remove addons-appset applicationset and corresponding appset-chart applicationset with orphan deletion policy. 
# The addons will be removed in specific order later.
# echo -e "${CYAN}🗑️  Deleting ${BOLD}addons-appset${NC} ${CYAN}ApplicationSet...${NC}"
# kubectl delete applicationsets.argoproj.io -n argocd addons-appset --cascade=orphan --kubeconfig $KUBECONFIG_FILE  > /dev/null 2>&1

# echo -e "${CYAN}🗑️  Deleting ${BOLD}appset-chart${NC} ${CYAN}ApplicationSet...${NC}"
# kubectl delete applications.argoproj.io -n argocd -l addonName=addons-appset --cascade=orphan --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1

# Start removing addons in order
echo -e "${BOLD}${YELLOW}📦 Removing add-ons in sequence...${NC}"
# Delete all addon application sets except argocd
for app in "${ADDONS[@]}"; do
  echo -e "${CYAN}🗑️  Deleting ${BOLD}$app${NC} ${CYAN}AppSet...${NC}"
  kubectl delete applicationsets.argoproj.io -n argocd $app --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
  # Wait for AppSet deletion to complete before moving to next AppSet
  while [ $(kubectl get applications.argoproj.io -n argocd -l addonName=$app --no-headers --kubeconfig $KUBECONFIG_FILE 2>/dev/null | wc -l) -ne 0 ]; do
    echo -e "${YELLOW}⏳ Waiting for ${BOLD}$app${NC} ${YELLOW}AppSet to be deleted...${NC}"
    sleep 10
  done
  echo -e "${GREEN}✅ ${BOLD}$app${NC} ${GREEN}successfully removed!${NC}"
done

# Delete ArgoCD App
echo -e "${CYAN}🗑️  Deleting ${BOLD}argocd${NC} ${CYAN}AppSet...${NC}"
kubectl delete applicationsets.argoproj.io -n argocd argocd --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true

# Wait for ArgoCD to be deleted
echo -e "${YELLOW}⏳ Waiting for ${BOLD}argocd${NC} ${YELLOW}AppSet to be deleted...${NC}"
START_TIME=$(date +%s)
TIMEOUT=120 # 2 minutes timeout
while [ $(kubectl get applications.argoproj.io -n argocd -l addonName=argocd --no-headers --kubeconfig $KUBECONFIG_FILE 2>/dev/null | wc -l) -ne 0 ]; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  
  if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠️ Timeout reached. Patching ${BOLD}argocd${NC} ${YELLOW}applications to remove finalizers...${NC}"
    kubectl patch applications.argoproj.io -n argocd argocd-hub --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' --kubeconfig $KUBECONFIG_FILE || true
    break
  fi
  
  echo -e "${YELLOW}⏳ Still waiting for ${BOLD}argocd${NC} ${YELLOW}AppSet to be deleted... (${ELAPSED_TIME}s elapsed)${NC}"
  sleep 10
done
echo -e "${GREEN}✅ ${BOLD}argocd${NC} ${GREEN}successfully removed!${NC}"

# Remove PVCs for keycloak
echo -e "${CYAN}🗑️  Deleting PVCs for ${BOLD}keycloak${NC}...${NC}"
kubectl delete pvc -n keycloak data-keycloak-postgresql-0 --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
kubectl delete pvc -n backstage data-postgresql-0 --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
echo -e "${GREEN}✅ Keycloak & Backstage Postgres PVCs removed!${NC}"

echo -e "\n${BOLD}${GREEN}🎉 Uninstallation Complete! 🎉${NC}"
echo -e "${CYAN}🧹 All resources have been successfully removed.${NC}"