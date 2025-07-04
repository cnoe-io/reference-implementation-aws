#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)
SECRET_NAME_PREFIX="cnoe-ref-impl"
PHASE="create-update-secrets"
source ${REPO_ROOT}/scripts/utils.sh

PRIVATE_DIR="$REPO_ROOT/private"

echo -e "\n${BOLD}${BLUE}🔐 Starting secret creation process...${NC}"
echo -e "${CYAN}📂 Reading files from:${NC} ${BOLD}${PRIVATE_DIR}${NC}"

if [ ! -d "$PRIVATE_DIR" ]; then
    echo -e "${RED}❌ Directory $PRIVATE_DIR does not exist${NC}"
    exit 1
fi

# Create or update secret
create_update_secret() {
   echo -e "\n${PURPLE}🚀 Creating/updating Secret for $1...${NC}"
   TAGS=$(get_tags_from_config)
   if aws secretsmanager create-secret \
      --name "$SECRET_NAME_PREFIX/$1" \
      --secret-string file://"$TEMP_SECRET_FILE" \
      --description "Secret created for $1 of CNOE AWS Reference Implementation" \
      --tags $TAGS \
      --region $AWS_REGION >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Secret '${BOLD}$SECRET_NAME_PREFIX/$1${NC}${GREEN}' created successfully!${NC}"
    else
      echo -e "${YELLOW}🔄 Secret exists, updating...${NC}"
      if aws secretsmanager update-secret \
         --secret-id "$SECRET_NAME_PREFIX/$1" \
         --secret-string file://"$TEMP_SECRET_FILE" \
         --region $AWS_REGION >/dev/null 2>&1; then
         echo -e "${GREEN}✅ Secret '${BOLD}$SECRET_NAME_PREFIX/$1${NC}${GREEN}' updated successfully!${NC}"
      else
         echo -e "${RED}❌ Failed to create/update secret${NC}"
         rm "$TEMP_SECRET_FILE"
         exit 1
      fi
   fi

   # Cleanup
   rm "$TEMP_SECRET_FILE"
   echo -e "${CYAN}🔐 Secret ARN:${NC} $(aws secretsmanager describe-secret --secret-id "$SECRET_NAME_PREFIX/$1" --region $AWS_REGION --query 'ARN' --output text)"
}

echo -e "\n${YELLOW}📋 Processing files...${NC}"
TEMP_SECRET_FILE=$(mktemp)

# Start building JSON for Github App secrets
echo "{" > "$TEMP_SECRET_FILE"

first=true
file_count=0
for file in "$PRIVATE_DIR"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .yaml)
        echo -e "${CYAN}  📄 Adding:${NC} ${filename}"
        
        # Add comma if not first entry
        if [ "$first" = false ]; then
            echo "," >> "$TEMP_SECRET_FILE"
        fi
        first=false
        
        # Add key-value pair with properly escaped content
        echo -n "  \"$filename\": " >> "$TEMP_SECRET_FILE"
        yq -o=json eval '.' "$file" >> "$TEMP_SECRET_FILE"
        file_count=$((file_count + 1))
    fi
done

if [ $file_count -eq 0 ]; then
    echo -e "${RED}❌ No files found in $PRIVATE_DIR${NC}"
    rm "$TEMP_SECRET_FILE"
    exit 1
fi

echo "" >> "$TEMP_SECRET_FILE"
echo "}" >> "$TEMP_SECRET_FILE"

create_update_secret "github-app"

# Build JSON for Config secret
TEMP_SECRET_FILE=$(mktemp)
yq -o=json eval '.' "$CONFIG_FILE" > "$TEMP_SECRET_FILE"
create_update_secret "config"

echo -e "\n${BOLD}${GREEN}🎉 Process completed successfully! 🎉${NC}"

