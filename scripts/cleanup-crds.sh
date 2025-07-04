#!/bin/bash

set -e -o pipefail

export REPO_ROOT=$(git rev-parse --show-toplevel)
PHASE="crd-uninstall"
source ${REPO_ROOT}/scripts/utils.sh

echo -e "\n${BOLD}${BLUE}🧹 Starting CRD cleanup process...${NC}"

CRDS=(
    "external-secrets.io"
    "argoproj.io" 
    "cert-manager.io"
    "crossplane.io"
    "externaldns.k8s.io"
)

TIMEOUT=60

cleanup_resources() {
    local crd=$1
    local kind=$(kubectl get crd $crd -o jsonpath='{.spec.names.kind}' --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || echo "")
    
    if [[ -z "$kind" ]]; then
        return
    fi
    
    echo -e "${CYAN}🔄 Cleaning up resources for CRD:${NC} ${BOLD}$crd${NC} ${CYAN}(Kind: $kind)${NC}"
    
    # Get all resources of this kind
    local resources=$(kubectl get $kind --all-namespaces -o name --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true)
    
    if [[ -z "$resources" ]]; then
        return
    fi
    
    # Delete resources
    echo "$resources" | while read resource; do
        if [[ -n "$resource" ]]; then
            echo -e "${YELLOW}🗑️  Deleting${NC} $resource"
            kubectl delete $resource --timeout=${TIMEOUT}s --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || {
                echo -e "${YELLOW}⏳ Timeout reached, force deleting${NC} $resource"
                kubectl patch $resource -p '{"metadata":{"finalizers":[]}}' --type=merge --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
                kubectl delete $resource --force --grace-period=0 --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
            }
        fi
    done
}

delete_crd() {
    local crd=$1
    echo -e "${RED}🗑️  Deleting CRD:${NC} ${BOLD}$crd${NC}"
    kubectl delete crd $crd --timeout=${TIMEOUT}s --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || {
        echo -e "${YELLOW}⏳ Timeout reached, removing finalizers for CRD${NC} ${BOLD}$crd${NC}"
        kubectl patch crd $crd -p '{"metadata":{"finalizers":[]}}' --type=merge --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
        kubectl delete crd $crd --force --grace-period=0 --kubeconfig $KUBECONFIG_FILE > /dev/null 2>&1 || true
    }
}

main() {
    echo -e "${PURPLE}📋 Starting CRD cleanup for groups:${NC} ${BOLD}${CRDS[@]}${NC}"
    
    for group in "${CRDS[@]}"; do
        echo -e "\n${CYAN}🔍 Processing CRD group:${NC} ${BOLD}$group${NC}"
        
        # Find CRDs with the group suffix
        crds=$(kubectl get crd -o name --kubeconfig $KUBECONFIG_FILE | grep "\.$group$" | cut -d'/' -f2 || true)
        
        if [[ -z "$crds" ]]; then
            echo -e "${YELLOW}⚠️  No CRDs found for group:${NC} $group"
            continue
        fi
        
        echo "$crds" | while read crd; do
            if [[ -n "$crd" ]]; then
                cleanup_resources "$crd"
                delete_crd "$crd"
                echo -e "${GREEN}✅ Successfully processed CRD:${NC} $crd"
            fi
        done
    done
    
    echo -e "\n${BOLD}${GREEN}🎉 CRD cleanup completed successfully! 🎉${NC}"
}

main

# Remove secrets created by the reference implementation
# echo -e "${CYAN}🔐 Cleaning up secrets...${NC}"
# kubectl get secrets -A --no-headers --kubeconfig $KUBECONFIG_FILE | awk '{ print $1, $2}' | xargs -n 2 kubectl delete secrets --kubeconfig $KUBECONFIG_FILE -n