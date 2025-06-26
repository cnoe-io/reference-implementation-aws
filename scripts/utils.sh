set -e
# Colors
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

check_command() {
  command -v "$1" >/dev/null 2>&1
}


# Validation
clis=("aws" "kubectl"  "yq")
for cli in "${clis[@]}"; do
  if check_command "$cli"; then
    continue
  else
    echo -e "${RED}$cli is not installed. Please install it to continue.${NC}"
    exit 4
  fi
done

# Fetch config values
export CLUSTER_NAME=$(yq '.cluster_name' $REPO_ROOT/config.yaml)
export AWS_REGION=$(yq '.region' $REPO_ROOT/config.yaml)
export DOMAIN_NAME=$(yq '.domain_name' $REPO_ROOT/config.yaml)
export PATH_ROUTING=$(yq '.path_routing' $REPO_ROOT/config.yaml)

# Header
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}"
echo -e "${BOLD}${CYAN}📦       CNOE AWS Reference Implementation    📦${NC}"
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}\n"

echo -e "${CYAN}📋 Configuration Details:${NC}"
echo -e "${YELLOW}----------------------------------------------------${NC}"
yq '... comments=""' ${REPO_ROOT}/config.yaml
echo -e "${YELLOW}----------------------------------------------------${NC}"

echo -e "${BOLD}${PURPLE}\n🎯 Targets:${NC}"
echo -e "${CYAN}🔶 Kubernetes cluster:${NC} ${BOLD}$CLUSTER_NAME${NC} in ${BOLD}$AWS_REGION${NC}"
echo -e "${CYAN}🔶 AWS profile (if set):${NC} ${AWS_PROFILE:-None}"
echo -e "${CYAN}🔶 AWS account number:${NC} $(aws sts get-caller-identity --query "Account" --output text)"

if [ $PHASE = "install" ]; then
  echo -e "\n${BOLD}${GREEN}❓ Are you sure you want to continue with installation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Installation cancelled.${NC}"
    exit 0
  fi
fi

if [ $PHASE = "uninstall" ]; then
  echo -e "\n${BOLD}${RED}⚠️  WARNING: This will remove all deployed resources!${NC}"
  echo -e "${BOLD}${RED}❓ Are you sure you want to continue with uninstallation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️  Uninstallation cancelled.${NC}"
    exit 0
  fi
fi

if [ $PHASE = "crd-uninstall" ]; then
  echo -e "\n${BOLD}${RED}⚠️  WARNING: This will remove all CRDs created by reference implementation!${NC}"
  echo -e "${BOLD}${RED}❓ Are you sure you want to continue with uninstallation?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️ CRD Uninstallation cancelled.${NC}"
    exit 0
  fi
fi

if [ $PHASE = "create-update-secrets" ]; then
  echo -e "${BOLD}${GREEN}❓ Are you sure you want to continue?${NC}"
  read -p '(yes/no): ' response
  if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}⚠️ Secret creation cancelled.${NC}"
    exit 0
  fi
fi

# Generate kubeconfig for the EKS cluster
export KUBECONFIG_FILE=$(mktemp)
echo -e "${PURPLE}🔑 Generating temporary kubeconfig for cluster ${BOLD}${CLUSTER_NAME}${NC}...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1