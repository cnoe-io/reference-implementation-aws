#!/bin/bash

set -e

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
    local kind=$(kubectl get crd $crd -o jsonpath='{.spec.names.kind}' 2>/dev/null || echo "")
    
    if [[ -z "$kind" ]]; then
        return
    fi
    
    echo "Cleaning up resources for CRD: $crd (Kind: $kind)"
    
    # Get all resources of this kind
    local resources=$(kubectl get $kind --all-namespaces -o name 2>/dev/null || true)
    
    if [[ -z "$resources" ]]; then
        return
    fi
    
    # Delete resources
    echo "$resources" | while read resource; do
        if [[ -n "$resource" ]]; then
            echo "Deleting $resource"
            kubectl delete $resource --timeout=${TIMEOUT}s 2>/dev/null || {
                echo "Timeout reached, force deleting $resource"
                kubectl patch $resource -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
                kubectl delete $resource --force --grace-period=0 2>/dev/null || true
            }
        fi
    done
}

delete_crd() {
    local crd=$1
    echo "Deleting CRD: $crd"
    kubectl delete crd $crd --timeout=${TIMEOUT}s 2>/dev/null || {
        echo "Timeout reached, removing finalizers for CRD $crd"
        kubectl patch crd $crd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        kubectl delete crd $crd --force --grace-period=0 2>/dev/null || true
    }
}

main() {
    echo "Starting CRD cleanup for groups: ${CRDS[@]}"
    
    for group in "${CRDS[@]}"; do
        echo "Processing crd: $group"
        
        # Find CRDs with the group suffix
        crds=$(kubectl get crd -o name | grep "\.$group$" | cut -d'/' -f2 || true)
        
        if [[ -z "$crds" ]]; then
            echo "No CRDs found for group: $group"
            continue
        fi
        
        echo "$crds" | while read crd; do
            if [[ -n "$crd" ]]; then
                cleanup_resources "$crd"
                delete_crd "$crd"
            fi
        done
    done
    
    echo "CRD cleanup completed"
}

main