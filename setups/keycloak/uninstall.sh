#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
LABEL_SELECTOR="controller.cert-manager.io/fao=true"
export APP_NAME=keycloak
export NAMESPACE=keycloak
export SECRET_STORE_NAME=${APP_NAME}
export SA_NAME=external-secret-${APP_NAME}

echo "backing up TLS secrets to ${REPO_ROOT}/private"

mkdir -p ${REPO_ROOT}/private
secrets=$(kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} --ignore-not-found)

if [[ ! -z "${secrets}" ]]; then
    kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} -o yaml > ${REPO_ROOT}/private/${APP_NAME}-tls-backup-$(date +%s).yaml
fi

cd ../external-secrets-configs
./uninstall.sh
cd -
kubectl delete -f secrets.yaml || true

kubectl delete -f argo-app.yaml || true
