#!/bin/bash

export APP_NAME=keycloak
export NAMESPACE=keycloak
export SECRET_STORE_NAME=keycloak
export SA_NAME=external-secret-keycloak
ROLE_NAME=cnoe-external-secret-keycloak
POLICY_NAME=cnoe-external-secret-keycloak

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo 'deleting external secrets'
envsubst < secret-store.yaml | kubectl delete -f -

echo 'deleting IAM Roles and Policies'
aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}

aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}
aws iam delete-role --role-name ${ROLE_NAME}

echo 'deleting secrets in Secrets Manager'
aws secretsmanager delete-secret --secret-id cnoe/keycloak/config --force-delete-without-recovery
