#!/bin/bash
set -e -o pipefail

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
    read -p "Enter your EKS Cluster Name: " CLUSTER_NAME
    export CLUSTER_NAME
fi

if [[ -z "${REGION}" ]]; then
    read -p "Enter your AWS Region: " REGION
    export REGION
fi

echo 'installing external secrets store'

export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text --region $REGION | sed -e "s/^https:\/\///")

envsubst < trust-policy.json > trust-policy-to-be-applied.json

envsubst < policy.json > policy-to-be-applied.json

echo 'creating AWS IAM policies and roles'
POLICY_OUTPUT=$(aws iam create-policy \
    --policy-name ${POLICY_NAME} \
    --policy-document file://policy-to-be-applied.json)

POLICY_ARN=$(echo $POLICY_OUTPUT | jq -r '.Policy.Arn')

ROLE_OUTPUT=$(aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://trust-policy-to-be-applied.json --description "For use with external secrets in keycloak namespace")

export ROLE_ARN=$(echo $ROLE_OUTPUT | jq -r '.Role.Arn')

aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN}

INPUT_STRING=$(envsubst < secrets-manager-input.json)

aws secretsmanager create-secret --name cnoe/keycloak/config --secret-string "${INPUT_STRING}"

envsubst < secret-store.yaml | kubectl apply -f -
echo 'waiting for external secrets to sync'
sleep 30
rm trust-policy-to-be-applied.json
rm policy-to-be-applied.json
