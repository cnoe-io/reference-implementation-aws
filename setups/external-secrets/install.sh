#!/bin/bash
set -e -o pipefail

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

envsubst '$GITHUB_URL'  < argo-app.yaml | kubectl apply -f -

echo "waiting for external secrets to be ready. may take a few minutes"
kubectl wait --for=jsonpath=.status.health.status=Healthy  --timeout=300s -f argo-app.yaml
