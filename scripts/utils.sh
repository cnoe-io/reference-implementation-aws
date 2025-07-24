set -e

# Colors
export RED='\033[38;5;160m'
export GREEN='\033[38;5;34m'
export PURPLE='\033[38;5;98m'
export NC='\033[0m'
export BLUE='\033[38;5;33m'
export YELLOW='\033[38;5;178m'
export CYAN='\033[38;5;37m'
export BOLD='\033[1m'
export ORANGE='\033[38;5;172m'

# Extract tags from config file
get_tags_from_config() {
    yq eval '.tags | to_entries | map("Key=" + .key + ",Value=" + .value) | join(" ")' "$CONFIG_FILE"
}

# Generate kubeconfig for the EKS cluster
get_kubeconfig() {
  export KUBECONFIG_FILE=$(mktemp)
  echo -e "${PURPLE}🔑 Generating temporary kubeconfig for cluster ${BOLD}${CLUSTER_NAME}${NC}...${NC}"
  aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1
}

# Wait for all Argo CD applications to report healthy status
wait_for_apps(){

  echo -e "${YELLOW}⏳ Waiting for addons-appset to be healthy...${NC}"
  kubectl wait --for=jsonpath=.status.health.status=Healthy  -n argocd applications/$APPSET_ADDON_NAME-$CLUSTER_NAME --timeout=15m --kubeconfig $KUBECONFIG_FILE
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

  echo -e "${YELLOW}⏳ Waiting for all Argo CD apps on the hub Cluster to be Healthy... might take up to 30 minutes${NC}"
  kubectl wait --for=jsonpath=.status.health.status=Healthy -n argocd --all applications --kubeconfig $KUBECONFIG_FILE --timeout=-30m
  echo -e "${BOLD}${GREEN}✅ All Argo CD apps are now healthy!${NC}"
}

# Check if required binaries binaries exists
clis=("aws" "kubectl"  "yq")
for cli in "${clis[@]}"; do
  if command -v "$cli" >/dev/null 2>&1 ; then
    continue
  else
    echo -e "${RED}❌ $cli command is not installed. Please install it to continue.${NC}"
    exit 4
  fi
done

export CONFIG_FILE="$REPO_ROOT/config.yaml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ File $CONFIG_FILE does not exist${NC}"
    exit 1
fi

# Fetch config values
export CLUSTER_NAME=$(yq '.cluster_name' "$CONFIG_FILE")
export AWS_REGION=$(yq '.region' "$CONFIG_FILE")
export DOMAIN_NAME=$(yq '.domain' "$CONFIG_FILE")
export PATH_ROUTING=$(yq '.path_routing' "$CONFIG_FILE")
export AUTO_MODE=$(yq '.auto_mode' "$CONFIG_FILE")
export APPSET_ADDON_NAME=$([[ "${PATH_ROUTING}" == "true" ]] && echo "addons-appset-pr" || echo "addons-appset")
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Header
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}"
echo -e "${BOLD}${CYAN}📦       CNOE AWS Reference Implementation    📦${NC}"
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}\n"

echo -e "${BOLD}${PURPLE}\n🎯 Targets:${NC}"
echo -e "${CYAN}🔶 AWS account number:${NC} ${AWS_ACCOUNT_ID}"
echo -e "${CYAN}🔶 AWS profile (if set):${NC} ${AWS_PROFILE:-None}"
echo -e "${CYAN}🔶 AWS region:${NC} ${AWS_REGION}"
echo -e "${CYAN}🔶 Kubernetes cluster:${NC} ${BOLD}$CLUSTER_NAME${NC}"

if [ $PHASE = "create-cluster" ]; then
  # Ask user for deployment tool
  echo -e "\n${BOLD}${YELLOW}❓ Which tool would you like to use for cluster creation?${NC}"
  echo -e "${CYAN}1) eksctl (YAML-based configuration)${NC}"
  echo -e "${CYAN}2) terraform (Infrastructure as Code)${NC}"
  read -p "Enter your choice (1 or 2): " tool_choice

  case $tool_choice in
      1)
          export DEPLOYMENT_TOOL="eksctl"
          echo -e "${GREEN}✅ Selected: eksctl${NC}"
          ;;
      2)
          export DEPLOYMENT_TOOL="terraform"
          echo -e "${GREEN}✅ Selected: terraform${NC}"
          ;;
      *)
          echo -e "${RED}❌ Invalid choice. Please select 1 or 2.${NC}"
          exit 1
          ;;
  esac

  # Ask user for cluster type
  echo -e "\n${BOLD}${YELLOW}❓ Which type of EKS cluster would you like to create?${NC}"
  echo -e "${CYAN}1) Auto Mode cluster (Recommended for new users)${NC}"
  echo -e "${CYAN}2) Non-Auto Mode cluster (Managed Node Groups)${NC}"
  read -p "Enter your choice (1 or 2): " cluster_choice

  case $cluster_choice in
      1)
          export CLUSTER_TYPE="auto"
          export AUTO_MODE="true"
          export EKSCTL_CONFIG_FILE_PATH="${REPO_ROOT}/cluster/eksctl/cluster-config-auto.yaml"
          echo -e "${GREEN}✅ Selected: Auto Mode cluster${NC}"
          ;;
      2)
          export CLUSTER_TYPE="standard"
          export AUTO_MODE="false"
          export EKSCTL_CONFIG_FILE_PATH="${REPO_ROOT}/cluster/eksctl/cluster-config.yaml"
          echo -e "${GREEN}✅ Selected: Non-Auto Mode cluster${NC}"
          ;;
      *)
          echo -e "${RED}❌ Invalid choice. Please select 1 or 2.${NC}"
          exit 1
          ;;
  esac
  echo -e "\n${BOLD}${GREEN}❓ Are you sure you want to create the EKS cluster?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
      echo -e "${YELLOW}⚠️ Cluster creation cancelled.${NC}"
      exit 0
  fi
fi

if [ $PHASE = "install" ]; then
  echo -e "${CYAN}📋 Configuration Details:${NC}"
  echo -e "${YELLOW}----------------------------------------------------${NC}"
  yq '... comments=""' "$CONFIG_FILE"
  echo -e "${YELLOW}----------------------------------------------------${NC}"

  echo -e "\n${BOLD}${GREEN}❓ Are you sure you want to continue with installation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Installation cancelled.${NC}"
    exit 0
  fi
  get_kubeconfig
fi

if [ $PHASE = "uninstall" ]; then
  echo -e "\n${BOLD}${RED}⚠️  WARNING: This will remove all deployed resources!${NC}"
  echo -e "${BOLD}${RED}❓ Are you sure you want to continue with uninstallation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Uninstallation cancelled.${NC}"
    exit 0
  fi
  get_kubeconfig
fi

if [ $PHASE = "crd-uninstall" ]; then
  echo -e "\n${BOLD}${RED}⚠️  WARNING: This will remove all CRDs created by reference implementation!${NC}"
  echo -e "${BOLD}${RED}❓ Are you sure you want to continue with uninstallation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️ CRD Uninstallation cancelled.${NC}"
    exit 0
  fi
  get_kubeconfig
fi

if [ $PHASE = "create-update-secrets" ]; then
  echo -e "${CYAN}🔐 Secret names:${NC} ${BOLD}${SECRET_NAME_PREFIX}/config & ${SECRET_NAME_PREFIX}/github-app ${NC}"
  echo -e "\n${BOLD}${RED}⚠️  WARNING: This will update the secrets if already they exists!!{NC}"
  echo -e "${BOLD}${GREEN}❓ Are you sure you want to continue?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️ Secret creation cancelled.${NC}"
    exit 0
  fi
fi
