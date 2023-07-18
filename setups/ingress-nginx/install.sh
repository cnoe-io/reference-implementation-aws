#!/bin/bash
set -e -o pipefail

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

echo 'creating Argo CD application for ingress-nginx'

envsubst '$GITHUB_URL' < argo-app.yaml | kubectl apply -f -
