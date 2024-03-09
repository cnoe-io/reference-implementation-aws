set -e
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


# Check if KUBECONFIG environment variable is set
if [ -z "$KUBECONFIG" ]; then
    DEFAULT_KUBECONFIG_FILE="$HOME/.kube/config"
    echo "KUBECONFIG variable is not set. Checking $DEFAULT_KUBECONFIG_FILE kubeconfig file."

    # Check if the default kubeconfig file exists
    if [ ! -f "${DEFAULT_KUBECONFIG_FILE}" ]; then
        echo "${DEFAULT_KUBECONFIG_FILE} kubeconfig file does not exist and KUBECONFIG environment variable is not set correctly."
        exit 1
    fi

    if [ "$( grep  -v "^$\|^ *$" -c  "${DEFAULT_KUBECONFIG_FILE}" )" -eq "0" ]; then
        echo -e "${RED}Error: ${DEFAULT_KUBECONFIG_FILE} kubeconfig file does not exist or is empty.${NC}"
        echo -e "${PURPLE}Info: Please configure a valid kubeconfig file or set the KUBECONFIG environment variable.${NC}"
        exit 1
    fi

else
    # Check if the kubeconfig file specified in the environment variable exists
    if [ ! -f "$KUBECONFIG" ]; then
        echo -e "${RED}Specified kubeconfig file '${KUBECONFIG}' does not exist.${NC}"
        exit 1
    fi
    export KUBECONFIG
fi

kubectl cluster-info > /dev/null
if [ $? -ne 0 ]; then
  echo "Could not get cluster info. Ensure kubectl is configured correctly"
  exit 1
fi

minor=$(kubectl version --client=true -o yaml | yq '.clientVersion.minor')
if [[ ${minor} -lt "27" ]]; then
  echo -e "${RED} ${minor} this kubectl version is not supported. Please upgrade to 1.27+ ${NC}"
  exit 5
fi
