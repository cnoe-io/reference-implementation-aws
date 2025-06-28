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

# Check if required binaries binaries exists
clis=("aws" "kubectl"  "yq")
for cli in "${clis[@]}"; do
  if command -v "$cli" >/dev/null 2>&1 ; then
    continue
  else
    echo -e "${RED}$cli is not installed. Please install it to continue.${NC}"
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
export PATH_ROUTING=$(yq '.auto_mode' "$CONFIG_FILE")

# Header
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}"
echo -e "${BOLD}${CYAN}📦       CNOE AWS Reference Implementation    📦${NC}"
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}\n"

echo -e "${BOLD}${PURPLE}\n🎯 Targets:${NC}"
echo -e "${CYAN}🔶 AWS account number:${NC} $(aws sts get-caller-identity --query "Account" --output text)"
echo -e "${CYAN}🔶 AWS profile (if set):${NC} ${AWS_PROFILE:-None}"
echo -e "${CYAN}🔶 AWS region:${NC} ${AWS_REGION}"
echo -e "${CYAN}🔶 Kubernetes cluster:${NC} ${BOLD}$CLUSTER_NAME${NC}"

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
