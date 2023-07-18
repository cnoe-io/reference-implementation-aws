#!/bin/bash
set -e -o pipefail

if [[ -z "${ARGO_SSO_ENABLED}" ]]; then
    while true; do
        read -p "Enable Argo workflows SSO with Kyelcoak? (yes or no): " yn
        case $yn in
            [Yy]* ) export ARGO_SSO_ENABLED=true;;
            [Nn]* ) export ARGO_SSO_ENABLED=false;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

if [[ "${ARGO_SSO_ENABLED}" == "true" ]]; then
  if [[ -z "${DOMAIN_NAME}" ]]; then
    read -p "Enter base domain name. For example, entering cnoe.io will set hostname to be keycloak.cnoe.io : " DOMAIN_NAME
  fi
  export ARGO_WORKFLOWS_DOMAIN_NAME="argo.${DOMAIN_NAME}"
  export KEYCLOAK_DOMAIN_NAME="keycloak.${DOMAIN_NAME}"

  echo "Creating keycloak client for Argo Workflows"

  ADMIN_PASSWORD=$(kubectl get secret -n keycloak keycloak-config -o go-template='{{index .data "KEYCLOAK_ADMIN_PASSWORD" | base64decode}}')
  kubectl port-forward -n keycloak svc/keycloak 8080:8080 > /dev/null 2>&1 &
  pid=$!
  trap '{
    rm config-payloads/*-to-be-applied.json || true
    kill $pid
  }' EXIT
  echo "waiting for port forward to be ready"
  while ! nc -vz localhost 8080 > /dev/null 2>&1 ; do
      sleep 2
  done

  KEYCLOAK_TOKEN=$(curl -sS  --fail-with-body -X POST -H "Content-Type: application/x-www-form-urlencoded"\
  --data-urlencode "username=cnoe-admin" \
  --data-urlencode "password=${ADMIN_PASSWORD}" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=admin-cli" \
  localhost:8080/realms/master/protocol/openid-connect/token | jq -e -r '.access_token')

  envsubst < config-payloads/client-payload.json > config-payloads/client-payload-to-be-applied.json

  curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X POST --data @config-payloads/client-payload-to-be-applied.json \
  localhost:8080/admin/realms/cnoe/clients

  CLIENT_ID=$(curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X GET localhost:8080/admin/realms/cnoe/clients | jq -e -r  '.[] | select(.clientId == "argo-workflows") | .id')

  export CLIENT_SECRET=$(curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X GET localhost:8080/admin/realms/cnoe/clients/${CLIENT_ID} | jq -e -r '.secret')

  CLIENT_SCOPE_GROUPS_ID=$(curl -sS -H "Content-Type: application/json" -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -X GET  localhost:8080/admin/realms/cnoe/client-scopes | jq -e -r  '.[] | select(.name == "groups") | .id')

  curl -sS -H "Content-Type: application/json" -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -X PUT  localhost:8080/admin/realms/cnoe/clients/${CLIENT_ID}/default-client-scopes/${CLIENT_SCOPE_GROUPS_ID}

  echo 'storing client secrets to argo namespace'
  kubectl create ns argo || true
  envsubst < secret-sso.yaml | kubectl apply -f -

  echo 'creating argo cd application'
  envsubst '$GITHUB_URL $KEYCLOAK_DOMAIN_NAME $ARGO_WORKFLOWS_DOMAIN_NAME' < argo-app.yaml | kubectl apply -f -

  echo "waiting for argo workflows to be ready. may take a few minutes"
  kubectl wait --for=jsonpath=.status.health.status=Healthy  --timeout=600s -f argo-app.yaml

  #If TLS secret is available in /private, use it. Could be empty...
  REPO_ROOT=$(git rev-parse --show-toplevel)

  if ls ${REPO_ROOT}/private/argo-workflows-tls-backup-* 1> /dev/null 2>&1; then
      TLS_FILE=$(ls -t ${REPO_ROOT}/private/argo-workflows-tls-backup-* | head -n1)
      kubectl apply -f ${TLS_FILE}
  fi

  echo 'creating ingress for argo workflows UI'
  envsubst < ingress.yaml | kubectl apply -f -
  echo 'create service accounts for SSO configurations'
  envsubst '$GITHUB_URL' < argo-app-sso-config.yaml | kubectl apply -f -
  exit 0
fi


echo 'creating Argo Workflows in your cluster...'
kubectl create ns argo || true

envsubst '$GITHUB_URL' < argo-app-no-sso.yaml | kubectl apply -f -
