export RED='\033[0;31m'
export GREEN='\033[0;32m'
export PURPLE='\033[0;35m'
export NC='\033[0m'

check_command() {
  command -v "$1" >/dev/null 2>&1
}

get_cleaned_domain_name() {
  url="$1"
  # Remove protocol (http://, https://) from the URL
  domain="${url#*://}"
  # Extract the domain name (everything before the first '/')
  domain="${domain%%/*}"
  # Remove any trailing dots or slashes from the domain name
  domain="${domain%.}"
  domain="${domain%/}"
  echo "$domain"
}

strip_trailing_slash() {
  input="$1"
  cleaned_input="${input%/}"
  echo "$cleaned_input"
}

install_apps() {
  local apps=("$@")
  SETUP_DIR="$(git rev-parse --show-toplevel)/setups"

  cd "${SETUP_DIR}/argocd/"
  ./install.sh
  cd -

  for app in "${apps[@]}"; do
    set +e
    exists=$(kubectl get -f "${SETUP_DIR}/${app}/argo-app.yaml")
    if [[ ! -z "${exists}" ]]; then
      echo -e "ArgoCD Application for ${GREEN}${app}${NC} already exists. Will not re-install."
      continue
    fi
    set -e
    echo -e "${GREEN}Installing ${app}${NC}"
    cd "${SETUP_DIR}/${app}/"
    ./install.sh
    cd -
    echo "------------"
  done
}

# Validation
clis=("aws" "kubectl" "jq" "kustomize" "curl")
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
