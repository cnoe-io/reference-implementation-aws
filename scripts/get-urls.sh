#!/bin/bash

# Colors
RED='\033[38;5;160m'
GREEN='\033[38;5;34m'
PURPLE='\033[38;5;98m'
NC='\033[0m'
BLUE='\033[38;5;33m'
YELLOW='\033[38;5;178m'
CYAN='\033[38;5;37m'
BOLD='\033[1m'
ORANGE='\033[38;5;172m'

# Get the path_routing value from config.yaml
PATH_ROUTING=$(yq '.path_routing' config.yaml)
# Get the domain from config.yaml
DOMAIN=$(yq '.domain' config.yaml)

echo -e "\n${BOLD}${ORANGE}✨ ========================================== ✨${NC}"
echo -e "${BOLD}${CYAN}🌐       Platform Access URLs                  🌐${NC}"
echo -e "${BOLD}${ORANGE}✨ ========================================== ✨${NC}\n"

echo -e "${BOLD}${PURPLE}🔗 URLs for accessing the platform:${NC}"
echo -e "${YELLOW}----------------------------------------------------${NC}"

if [ "$PATH_ROUTING" == "\"true\"" ] || [ "$PATH_ROUTING" == "true" ]; then
  echo -e "${CYAN}🔶 Backstage:      ${BOLD}https://$DOMAIN${NC}"
  echo -e "${CYAN}🔶 Argo CD:        ${BOLD}https://$DOMAIN/argocd${NC}"
  echo -e "${CYAN}🔶 Argo Workflows: ${BOLD}https://$DOMAIN/argo-workflows${NC}"
else
  echo -e "${CYAN}🔶 Backstage:      ${BOLD}https://backstage.$DOMAIN${NC}"
  echo -e "${CYAN}🔶 Argo CD:        ${BOLD}https://argocd.$DOMAIN${NC}"
  echo -e "${CYAN}🔶 Argo Workflows: ${BOLD}https://argo-workflows.$DOMAIN${NC}"
fi

echo -e "${YELLOW}----------------------------------------------------${NC}"
echo -e "\n${BOLD}${GREEN}✅ Use the URLs above to access the platform services${NC}\n"