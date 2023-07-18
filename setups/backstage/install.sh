#!/bin/bash
set -e -o pipefail

if [[ -z "${BACKSTAGE_SSO_ENABLED}" ]]; then
    while true; do
        read -p "Enable Backstage SSO with Kyelcoak? (yes or no): " yn
        case $yn in
            [Yy]* ) export BACKSTAGE_SSO_ENABLED=true;;
            [Nn]* ) export BACKSTAGE_SSO_ENABLED=false;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

if [[ "${BACKSTAGE_SSO_ENABLED}" == "true" ]]; then
  if [[ -z "${DOMAIN_NAME}" ]]; then
    read -p "Enter base domain name. For example, entering cnoe.io will set hostname to be keycloak.cnoe.io : " DOMAIN_NAME
  fi
  export BACKSTAGE_DOMAIN_NAME="idp.${DOMAIN_NAME}"
  export BACKSTAGE_API_DOMAIN_NAME="idp-api.${DOMAIN_NAME}"
  export KEYCLOAK_DOMAIN_NAME="keycloak.${DOMAIN_NAME}"

  echo "Creating keycloak client for Backstage"

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
  -X GET localhost:8080/admin/realms/cnoe/clients | jq -e -r  '.[] | select(.clientId == "backstage") | .id')

  export CLIENT_SECRET=$(curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X GET localhost:8080/admin/realms/cnoe/clients/${CLIENT_ID} | jq -e -r '.secret')

  echo 'storing client secrets to backstage namespace'
  kubectl create ns backstage || true
  envsubst < secret-sso.yaml | kubectl apply -f -

  echo 'creating argo CD application for Backstage'
  envsubst '$GITHUB_URL $KEYCLOAK_DOMAIN_NAME $BACKSTAGE_DOMAIN_NAME' < argo-app.yaml | kubectl apply -f -

  echo "waiting for backstage to be ready. may take a few minutes"
  kubectl wait --for=jsonpath=.status.health.status=Healthy  --timeout=600s -f argo-app.yaml

  echo 'creating ingresses for Backstage'
  envsubst < ingress-frontend.yaml | kubectl apply -f -
  envsubst < ingress-backend.yaml | kubectl apply -f -
  echo 'create service accounts for SSO configurations'
  envsubst '$GITHUB_URL' < argo-app-sso-config.yaml | kubectl apply -f -
  exit 0
fi


echo 'creating argo CD application for Backstage'
kubectl create ns backstage || true

envsubst '$GITHUB_URL' < argo-app.yaml | kubectl apply -f -
