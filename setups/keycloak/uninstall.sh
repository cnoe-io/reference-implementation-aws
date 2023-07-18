#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
NAMESPACE="keycloak"
LABEL_SELECTOR="controller.cert-manager.io/fao=true"

echo "backing up TLS secrets to ${REPO_ROOT}/private"

mkdir -p ${REPO_ROOT}/private
kubectl get secrets -n keycloak -l controller.cert-manager.io/fao=true -o yaml > ${REPO_ROOT}/private/keycloak-tls-backup-$(date +%s).yaml


kubectl delete -f secrets.yaml || true
kubectl delete -f argo-app.yaml || true
