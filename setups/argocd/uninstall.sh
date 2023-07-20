#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
kustomize build ${REPO_ROOT}/packages/argocd/dev  | kubectl delete -f -

kubectl delete ns argocd || true
