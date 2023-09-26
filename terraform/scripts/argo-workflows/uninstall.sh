#!/bin/bash
set -e -o pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
NAMESPACE="argo"
LABEL_SELECTOR="controller.cert-manager.io/fao=true"
NAME=argo-workflows


echo "backing up TLS secrets to ${REPO_ROOT}/private"

mkdir -p ${REPO_ROOT}/private
secrets=$(kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} --ignore-not-found)

if [[ ! -z "${secrets}" ]]; then
    kubectl get secrets -n ${NAMESPACE} -l ${LABEL_SELECTOR} -o yaml > ${REPO_ROOT}/private/${NAME}-tls-backup-$(date +%s).yaml
fi

kubectl delete -f secret-sso.yaml || true

ADMIN_PASSWORD=$(kubectl get secret -n keycloak keycloak-config -o go-template='{{index .data "KEYCLOAK_ADMIN_PASSWORD" | base64decode}}')

kubectl port-forward -n keycloak svc/keycloak 8090:8080 > /dev/null 2>&1 &
pid=$!
trap '{
kill $pid
}' EXIT

echo "waiting for port forward to be ready"
while ! nc -vz localhost 8090 > /dev/null 2>&1 ; do
    sleep 2
done

echo 'deleting Keycloak client'
KEYCLOAK_TOKEN=$(curl -sS  --fail-with-body -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "username=cnoe-admin" \
  --data-urlencode "password=${ADMIN_PASSWORD}" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=admin-cli" \
  localhost:8090/realms/master/protocol/openid-connect/token | jq -e -r '.access_token')

CLIENT_ID=$(curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X GET localhost:8090/admin/realms/cnoe/clients | jq -e -r  '.[] | select(.clientId == "argo-workflows") | .id')

curl -sS -H "Content-Type: application/json" \
  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" \
  -X DELETE localhost:8090/admin/realms/cnoe/clients/${CLIENT_ID}

