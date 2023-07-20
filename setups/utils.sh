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

# Validation
clis=("aws" "kubectl" "jq" "npx" "kustomize")
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
  echo "An error occurred. Exiting..."
  # Add cleanup code here if needed
  exit 1
fi