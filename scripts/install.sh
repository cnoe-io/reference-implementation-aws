#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)
PHASE="install"
source ${REPO_ROOT}/scripts/utils.sh

echo -e "\n${BOLD}${BLUE}🚀 Starting installation process...${NC}"
yq -i '.spec.destination.name = "'"$CLUSTER_NAME"'"' packages/addons-appset.yaml # To set the Remote EKS Cluster name in Addon AppSet chart
echo -e "${CYAN}📡 Connecting to cluster:${NC} ${BOLD}${CLUSTER_NAME}${NC} in ${BOLD}${AWS_REGION}${NC}"

SERVER_URL=$(cat "$KUBECONFIG_FILE" | yq -r '.clusters[0].cluster.server')
CA_DATA=$(cat "$KUBECONFIG_FILE" | yq -r '.clusters[0].cluster."certificate-authority-data"')

echo -e "${CYAN}📝 Creating cluster secret file...${NC}"
CLUSTER_SECRET_FILE=$(mktemp)
cat << EOF > "$CLUSTER_SECRET_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: "$CLUSTER_NAME-cluster-secret"
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster 
    clusterClass: "control-plane"
    clusterName: "$CLUSTER_NAME"
    environment: "control-plane"
    path_routing: "$PATH_ROUTING"
  annotations:
    addons_repo_url: "http://cnoe.localtest.me:8443/gitea/giteaAdmin/idpbuilder-localdev-bootstrap-appset-packages.git"
    addons_repo_revision: "HEAD" 
    addons_repo_basepath: "." 
    domain: "$DOMAIN_NAME"
type: Opaque
stringData:
  name: "$CLUSTER_NAME"
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
idpbuilder create --use-path-routing --protocol http --package "$REPO_ROOT/packages" -c "argocd:${CLUSTER_SECRET_FILE}" > /dev/null 2>&1

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
  
  echo -e "${YELLOW}⏳ Still waiting for ${BOLD}argocd apps from Appset chart${NC} ${YELLOW}to be created on hub cluster... (${ELAPSED_TIME}s elapsed)${NC}"
  sleep 30
done

echo -e "${YELLOW}⏳ Waiting for all Argo CD apps on the hub Cluster to be Healthy...${NC}"
kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd --all applications --kubeconfig $KUBECONFIG_FILE --timeout=-30m
echo -e "${BOLD}${GREEN}✅ All Argo CD apps are now healthy!${NC}"

echo -e "\n${BOLD}${BLUE}🎉 Installation completed successfully! 🎉${NC}"
echo -e "${CYAN}📊 You can now access your resources and start deploying applications.${NC}"