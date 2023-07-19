#!/bin/bash
set -e -o pipefail

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

echo 'creating Argo CD application for cert-manager'

envsubst '$GITHUB_URL' < argo-app.yaml | kubectl apply -f -

echo 'waiting for ArgoCD application to be ready'
kubectl wait --for=jsonpath=.status.health.status=Healthy --timeout=600s -f argo-app.yaml

echo "creating lets encrypt ClusterIssuers"
envsubst < letsencrypt-prod.yaml | kubectl apply -f -
envsubst < letsencrypt-staging.yaml | kubectl apply -f -
