#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)
PHASE="install"
source ${REPO_ROOT}/scripts/utils.sh

echo -e "\n${BOLD}${BLUE}🚀 Starting installation process...${NC}"

SERVER_URL=$(cat "$KUBECONFIG_FILE" | yq -r '.clusters[0].cluster.server')
CA_DATA=$(cat "$KUBECONFIG_FILE" | yq -r '.clusters[0].cluster."certificate-authority-data"')

echo -e "${CYAN}📝 Creating cluster secret file...${NC}"
CLUSTER_SECRET_FILE=$(mktemp)
cat << EOF > "$CLUSTER_SECRET_FILE"
# Remote EKS cluster Argo CD secret
apiVersion: v1
kind: Secret
metadata:
  name: "$CLUSTER_NAME-cluster-secret"
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster 
    clusterClass: "control-plane"
    clusterName: "$CLUSTER_NAME"
    environment: "control-plane-bootstrap"
    path_routing: "$PATH_ROUTING"
    auto_mode: "$AUTO_MODE"
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

echo -e "${YELLOW}⏳ Waiting for local addons-appset to be healthy...${NC}"
# sleep 60 # Wait 1 minute before checking the status
kubectl wait --for=jsonpath=.status.health.status=Healthy  -n argocd applications/addons-appset-$CLUSTER_NAME --timeout=15m
echo -e "${GREEN}✅ local addons-appset is now healthy!${NC}"

# Wait for Argo CD applications to sync
wait_for_apps

# Delete idpbuilder local kind cluster instance
echo -e "${CYAN}🔄 Deleting idpbuilder local kind cluster instance...${NC}"
idpbuilder delete cluster --name localdev > /dev/null 2>&1

echo -e "\n${BOLD}${BLUE}🎉 Installation completed successfully! 🎉${NC}"
echo -e "${CYAN}📊 You can now access your resources and start deploying applications.${NC}"