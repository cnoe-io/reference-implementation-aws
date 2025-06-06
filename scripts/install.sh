#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)

source ${REPO_ROOT}/scripts/utils.sh

echo -e "${GREEN}Installing with the following options: ${NC}"
echo -e "${GREEN}----------------------------------------------------${NC}"
yq '... comments=""' ${REPO_ROOT}/config.yaml
echo -e "${GREEN}----------------------------------------------------${NC}"
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

CLUSTER_NAME=$(yq '.cluster_name' config.yaml)
AWS_REGION=$(yq '.region' config.yaml)



KUBECONFIG_FILE=$(mktemp)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE
KUBECONFIG=$(kubectl config --kubeconfig $KUBECONFIG_FILE view --raw -o json)
SERVER_URL=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster.server')
CA_DATA=$(echo $KUBECONFIG | jq -r '.clusters[0].cluster."certificate-authority-data"')

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

# Run idpbuilder for applying packages
idpbuilder create --use-path-routing --protocol http --package "$REPO_ROOT/packages/" -c "argocd:${CLUSTER_SECRET_FILE}"

# Apply remote cluster secret
# kubectl apply -f "$CLUSTER_SECRET_FILE"


# REPO_ROOT=$(git rev-parse --show-toplevel)

# source ${REPO_ROOT}/setups/utils.sh

# echo -e "${GREEN}Installing with the following options: ${NC}"
# echo -e "${GREEN}----------------------------------------------------${NC}"
# yq '... comments=""' ${REPO_ROOT}/setups/config.yaml
# echo -e "${GREEN}----------------------------------------------------${NC}"
# echo -e "${PURPLE}\nTargets:${NC}"
# echo "Kubernetes cluster: $(kubectl config current-context)"
# echo "AWS profile (if set): ${AWS_PROFILE}"
# echo "AWS account number: $(aws sts get-caller-identity --query "Account" --output text)"

# echo -e "${GREEN}\nAre you sure you want to continue?${NC}"
# read -p '(yes/no): ' response
# if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
#   echo 'exiting.'
#   exit 0
# fi

# export GITHUB_URL=$(yq '.repo_url' ./setups/config.yaml)

# # Set up ArgoCD. We will use ArgoCD to install all components.
# cd "${REPO_ROOT}/setups/argocd/"
# ./install.sh
# cd -

# # The rest of the steps are defined as a Terraform module. Parse the config to JSON and use it as the Terraform variable file. This is done because JSON doesn't allow you to easily place comments.
# cd "${REPO_ROOT}/terraform/"
# yq -o json '.'  ../setups/config.yaml > terraform.tfvars.json
# terraform init -upgrade
# terraform apply -auto-approve
