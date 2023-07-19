#!/bin/bash
set -e -o pipefail

echo 'To get started grant the following permissions: 
  - Repository access for all repositories
  - Read-only access to: Administration, Contents, and Metadata.
Get your GitHub personal access token from: https://github.com/settings/tokens?type=beta'
echo "Enter your token. e.g. github_pat_abcde: "
read -s GITHUB_TOKEN
read -p "Enter GitHub organization URL. e.g. https://github.com/cnoe-io : " GITHUB_URL

export GITHUB_URL
export GITHUB_TOKEN

echo 'creating secret for ArgoCD in your cluster...'
kubectl create ns argocd || true
envsubst < github-secret.yaml  | kubectl apply -f - 

REPO_ROOT=$(git rev-parse --show-toplevel)

echo 'creating Argo CD resources'
cd ${REPO_ROOT}
kustomize build packages/argocd/dev  | kubectl apply -f -
cd -
