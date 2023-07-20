#!/bin/bash
set -e -o pipefail

echo 'To get started grant the following permissions: 
  - Repository access for all repositories
  - Read-only access to: Administration, Contents, and Metadata.
Get your GitHub personal access token from: https://github.com/settings/tokens?type=beta'
echo "Enter your token. e.g. github_pat_abcde: "
read -s GITHUB_TOKEN

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

export GITHUB_TOKEN

echo 'creating secret for ArgoCD in your cluster...'
kubectl create ns argocd || true
envsubst < github-secret.yaml  | kubectl apply -f - 

REPO_ROOT=$(git rev-parse --show-toplevel)

echo 'creating Argo CD resources'
cd ${REPO_ROOT}
kustomize build packages/argocd/dev  | kubectl apply -f -
echo 'waiting for ArgoCD to be ready'
kubectl -n argocd rollout status --watch --timeout=300s statefulset/argocd-application-controller
cd -
