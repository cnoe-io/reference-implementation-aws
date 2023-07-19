#!/bin/bash
set -e -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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

# Validation
clis=("aws" "kubectl" "jq" "npx")
for cli in "${clis[@]}"; do
  if check_command "$cli"; then
    continue
  else
    echo -e "${RED}$cli is not installed. Please install it to continue.${NC}"
    exit 4
  fi
done

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}/setups
env_file=${REPO_ROOT}/setups/config

while IFS='=' read -r key value; do
  [[ $key == \#* ]] && continue
  export "$key"="$value"
done < $env_file

if [[ ! -z "${GITHUB_URL}" ]]; then
    export GITHUB_URL=$(strip_trailing_slash "${GITHUB_URL}")
fi

if [[ ! -z "${DOMAIN_NAME}" ]]; then
    export DOMAIN_NAME=$(get_cleaned_domain_name "${DOMAIN_NAME}")
fi

env_vars=("GITHUB_URL" "DOMAIN_NAME" "BACKSTAGE_SSO_ENABLED" "ARGO_SSO_ENABLED" "CLUSTER_NAME" "REGION")

echo -e "${GREEN}installing with the following options \n ${NC}"
for env_var in "${env_vars[@]}"; do
  echo -e "${env_var}: ${!env_var}"
done
cd - 