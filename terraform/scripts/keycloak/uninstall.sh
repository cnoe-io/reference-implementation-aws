#!/bin/bash

LABEL_SELECTOR="controller.cert-manager.io/fao=true"
APP_NAME=keycloak
NAMESPACE=keycloak
REPO_ROOT=$(git rev-parse --show-toplevel)

echo "backing up TLS secrets to ${REPO_ROOT}/private"

mkdir -p ${REPO_ROOT}/private
secrets=$(kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} --ignore-not-found)

if [[ ! -z "${secrets}" ]]; then
    kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} -o yaml > ${REPO_ROOT}/private/${APP_NAME}-tls-backup-$(date +%s).yaml
fi
