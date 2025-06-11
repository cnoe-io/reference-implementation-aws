#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)

source ${REPO_ROOT}/scripts/utils.sh

CLUSTER_NAME=$(yq '.cluster_name' config.yaml)
AWS_REGION=$(yq '.region' config.yaml)

# Additional colors
export BLUE='\033[0;34m'
export YELLOW='\033[0;33m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'

# Header
echo -e "${BOLD}${BLUE}✨ ========================================== ✨${NC}"
echo -e "${BOLD}${BLUE}📦       CNOE AWS Reference Implementation    📦${NC}"
echo -e "${BOLD}${BLUE}✨ ========================================== ✨${NC}\n"

echo -e "${BOLD}${GREEN}🔧 Installing with the following options: ${NC}"
echo -e "${CYAN}📋 Configuration Details:${NC}"
echo -e "${YELLOW}----------------------------------------------------${NC}"
yq '... comments=""' ${REPO_ROOT}/config.yaml
echo -e "${YELLOW}----------------------------------------------------${NC}"

echo -e "${BOLD}${PURPLE}\n🎯 Targets:${NC}"
echo -e "${CYAN}🔶 Kubernetes cluster:${NC} $(kubectl config current-context)"
echo -e "${CYAN}🔶 AWS profile (if set):${NC} ${AWS_PROFILE:-None}"
echo -e "${CYAN}🔶 AWS account number:${NC} $(aws sts get-caller-identity --query "Account" --output text)"

echo -e "\n${BOLD}${GREEN}❓ Are you sure you want to continue?${NC}"
read -p '(yes/no): ' response
if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo -e "${YELLOW}⚠️  Installation cancelled.${NC}"
  exit 0
fi

echo -e "\n${BOLD}${BLUE}🚀 Starting installation process...${NC}"

echo -e "${CYAN}📡 Connecting to cluster:${NC} ${BOLD}${CLUSTER_NAME}${NC} in ${BOLD}${AWS_REGION}${NC}"

KUBECONFIG_FILE=$(mktemp)
echo -e "${PURPLE}🔑 Generating temporary kubeconfig for cluster ${BOLD}${CLUSTER_NAME}${NC}...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1
KUBECONFIG=$(kubectl config --kubeconfig $KUBECONFIG_FILE view --raw -o json)
SERVER_URL=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster.server')
CA_DATA=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster."certificate-authority-data"')

echo -e "${CYAN}📝 Creating cluster secret file...${NC}"
CLUSTER_SECRET_FILE=$(mktemp)
cat << EOF > "$CLUSTER_SECRET_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: hub
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: hub
  server: $SERVER_URL
  clusterResources: "true"
  config: |
    {
      "execProviderConfig": {
        "command": "argocd-k8s-auth",
        "args": ["aws", "--cluster-name", "$CLUSTER_NAME"],
        "apiVersion": "client.authentication.k8s.io/v1beta1"
      },
      "tlsClientConfig": {
        "insecure": false,
        "caData": "$CA_DATA"
      }
    }
EOF

echo -e "${BOLD}${GREEN}🔄 Running idpbuilder to apply packages...${NC}"
idpbuilder create --use-path-routing --protocol http --package "$REPO_ROOT/packages/" -c "argocd:${CLUSTER_SECRET_FILE}"

echo -e "${YELLOW}⏳ Waiting for hub-addons to be healthy...${NC}"
kubectl wait --for=jsonpath=.status.health.status=Healthy  -n argocd application/hub-addons --timeout=5m
echo -e "${GREEN}✅ hub-addons is now healthy!${NC}"
sleep 30

echo -e "${YELLOW}⏳ Waiting for ArgoCD on the hub Cluster to be Healthy...${NC}"
kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd application/argocd-hub --kubeconfig $KUBECONFIG_FILE --timeout=-15m
echo -e "${BOLD}${GREEN}✅ ArgoCD is now healthy!${NC}"

echo -e "\n${BOLD}${BLUE}🎉 Installation completed successfully! 🎉${NC}"
echo -e "${CYAN}📊 You can now access your resources and start deploying applications.${NC}"