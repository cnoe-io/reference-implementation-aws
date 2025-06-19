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
    clusterClass: "control-plane"
    clusterName: "hub"
    environment: "control-plane"
    path_routing: "true" # Set to false to disable path routing # TODO: Fetch config values here
  annotations:
    addons_repo_url: "http://cnoe.localtest.me:8443/gitea/giteaAdmin/idpbuilder-localdev-bootstrap-appset-packages.git"
    addons_repo_revision: "HEAD" 
    addons_repo_basepath: "." 
    domain: advaitt.people.aws.dev # TODO: Fetch config values here
    oidc_provider: keycloak
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
idpbuilder create --use-path-routing --protocol http --package "$REPO_ROOT/packages" -c "argocd:${CLUSTER_SECRET_FILE}"

echo -e "${YELLOW}⏳ Waiting for addons-appset to be healthy...${NC}"
# sleep 60 # Wait 1 minute before checking the status
kubectl wait --for=jsonpath=.status.health.status=Healthy  -n argocd applications/addons-appset --timeout=15m
echo -e "${GREEN}✅ addons-appset is now healthy!${NC}"

START_TIME=$(date +%s)
TIMEOUT=600 # 5 minute timeout for moving to checking the status as the apps on hub cluster will take some time to create
while [ $(kubectl get applications.argoproj.io -n argocd  --no-headers --kubeconfig $KUBECONFIG_FILE 2>/dev/null | wc -l) -lt 2 ]; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  
  if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠️ Timeout reached while waiting for applications to be created by the AppSet chart...${NC}"
    break
  fi
  
  echo -e "${YELLOW}⏳ Still waiting for ${BOLD}argocd apps from Appset chart${NC} ${YELLOW} to be created on hub cluster... (${ELAPSED_TIME}s elapsed)${NC}"
  sleep 30
done

echo -e "${YELLOW}⏳ Waiting for all Argo CD apps on the hub Cluster to be Healthy...${NC}"
kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd --all applications --kubeconfig $KUBECONFIG_FILE --timeout=-30m
echo -e "${BOLD}${GREEN}✅ All Argo CD apps are now healthy!${NC}"

echo -e "\n${BOLD}${BLUE}🎉 Installation completed successfully! 🎉${NC}"
echo -e "${CYAN}📊 You can now access your resources and start deploying applications.${NC}"