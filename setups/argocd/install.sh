#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)

if [ -f "${REPO_ROOT}/private/github-token" ]; then
  GITHUB_TOKEN=$(cat ${REPO_ROOT}/private/github-token | tr -d '\n')
else
  echo 'To get started grant the following permissions: 
  - Repository access for all repositories
  - Read-only access to: Administration, Contents, and Metadata.
  Get your GitHub personal access token from: https://github.com/settings/tokens?type=beta'
  echo "Enter your token. e.g. github_pat_abcde: "
  read -s GITHUB_TOKEN
fi


if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

export GITHUB_TOKEN

echo 'creating secret for ArgoCD in your cluster...'
kubectl create ns argocd || true
envsubst < github-secret.yaml  | kubectl apply -f - 

echo 'creating Argo CD resources'
cd ${REPO_ROOT}
retry_count=0
max_retries=2

set +e
while [ $retry_count -le $max_retries ]; do
  kustomize build packages/argocd/dev  | kubectl apply -f -
  if [ $? -eq 0 ]; then
    break
  fi
  echo "An error occurred. Retrying in 5 seconds"
  sleep 5
  ((retry_count++))
done

if [ $? -ne 0 ]; then
  echo 'could not install argocd in your cluster'
  exit 1
fi

set -e
echo 'waiting for ArgoCD to be ready'
kubectl -n argocd rollout status --watch --timeout=300s statefulset/argocd-application-controller
kubectl -n argocd rollout status --watch --timeout=300s deployment/argocd-server

cd -
