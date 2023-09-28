export RED='\033[0;31m'
export GREEN='\033[0;32m'
export PURPLE='\033[0;35m'
export NC='\033[0m'

check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Validation
clis=("aws" "kubectl" "jq" "kustomize" "curl" "yq")
for cli in "${clis[@]}"; do
  if check_command "$cli"; then
    continue
  else
    echo -e "${RED}$cli is not installed. Please install it to continue.${NC}"
    exit 4
  fi
done


kubectl cluster-info > /dev/null
if [ $? -ne 0 ]; then
  echo "Could not get cluster info. Ensure kubectl is configured correctly"
  exit 1
fi

minor=$(kubectl version --client=true -o yaml | yq '.clientVersion.minor')
if [[ ${minor} -lt "27" ]]; then
  echo -e "${RED}this kubectl version is not supported. Please upgrade to 1.27+ ${NC}"
  exit 5
fi
