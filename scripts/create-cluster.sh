#!/bin/bash
set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)
PHASE="create-cluster"
echo -e "\n${BOLD}${BLUE}🚀 Starting EKS cluster creation process...${NC}"

source ${REPO_ROOT}/scripts/utils.sh

# Check required tools based on deployment choice
if [ "$DEPLOYMENT_TOOL" = "eksctl" ]; then
    if ! command -v eksctl >/dev/null 2>&1; then
        echo -e "${RED}❌ eksctl command is not installed. Please install it to continue.${NC}"
        echo -e "${CYAN}💡 Installation instructions: https://eksctl.io/installation/${NC}"
        exit 1
    fi
elif [ "$DEPLOYMENT_TOOL" = "terraform" ]; then
    if ! command -v terraform >/dev/null 2>&1; then
        echo -e "${RED}❌ terraform command is not installed. Please install it to continue.${NC}"
        echo -e "${CYAN}💡 Installation instructions: https://terraform.io/downloads${NC}"
        exit 1
    fi
fi

echo -e "\n${BOLD}${BLUE}🚀 Creating EKS cluster...${NC}"
echo -e "${YELLOW}⏳ This process may take 15-20 minutes...${NC}"

# Create the cluster based on deployment tool
if [ "$DEPLOYMENT_TOOL" = "eksctl" ]; then
    echo -e "\n${BOLD}${BLUE}🔧 Creating Crossplane permissions boundary policy...${NC}"

    # Create temporary file for policy document
    TEMPFILE=$(mktemp)
    sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" ${REPO_ROOT}/cluster/iam-policies/crossplane-permissions-boundry.json > "$TEMPFILE"

    echo -e "${CYAN}📋 Creating IAM policy crossplane-permissions-boundary...${NC}"

    # Create the permissions boundary policy (ignore error if it already exists)
    if aws iam create-policy \
        --policy-name crossplane-permissions-boundary \
        --policy-document file://"$TEMPFILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Created crossplane-permissions-boundary policy${NC}"
    else
        echo -e "${YELLOW}⚠️ Policy crossplane-permissions-boundary already exists, continuing...${NC}"
    fi

    # Get the policy ARN
    export CROSSPLANE_BOUNDARY_POLICY_ARN=$(aws iam get-policy \
        --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/crossplane-permissions-boundary \
        --query 'Policy.Arn' --output text)

    echo -e "${CYAN}🔗 Policy ARN:${NC} ${CROSSPLANE_BOUNDARY_POLICY_ARN}"

    # Clean up temp file
    rm -f "$TEMPFILE"
    echo -e "${CYAN}🔧 Using eksctl for cluster creation...${NC}"
    
    # Create the cluster with eksctl
    sed -e "s/\${CLUSTER_NAME}/${CLUSTER_NAME}/g" \
        -e "s/\${AWS_REGION}/${AWS_REGION}/g" \
        -e "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" \
        -e "s/\${CROSSPLANE_BOUNDARY_POLICY_ARN}/${CROSSPLANE_BOUNDARY_POLICY_ARN//\//\\/}/g" \
        "$EKSCTL_CONFIG_FILE_PATH" | eksctl create cluster -f -
        
elif [ "$DEPLOYMENT_TOOL" = "terraform" ]; then
    echo -e "${CYAN}🔧 Using terraform for cluster creation...${NC}"
    
    # Set terraform variables
    export TF_VAR_cluster_name="$CLUSTER_NAME"
    export TF_VAR_region="$AWS_REGION"
    export TF_VAR_auto_mode="$AUTO_MODE"
    
    # Initialize and apply terraform
    terraform -chdir="$REPO_ROOT/cluster/terraform" init
    terraform -chdir="$REPO_ROOT/cluster/terraform" apply -auto-approve
fi

echo -e "\n${BOLD}${GREEN}🎉 EKS cluster created successfully! 🎉${NC}"
echo -e "${CYAN}📊 Cluster Details:${NC}"
echo -e "${CYAN}🔶 Name:${NC} ${BOLD}${CLUSTER_NAME}${NC}"
echo -e "${CYAN}🔶 Region:${NC} ${AWS_REGION}"
echo -e "${CYAN}🔶 Type:${NC} ${CLUSTER_TYPE}"
echo -e "${CYAN}🔶 Tool:${NC} ${DEPLOYMENT_TOOL}"

echo -e "\n${BOLD}${BLUE}🔧 Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} --alias ${CLUSTER_NAME} 

echo -e "\n${BOLD}${GREEN}✅ Cluster is ready for CNOE reference implementation installation!${NC}"