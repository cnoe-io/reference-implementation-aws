#!/bin/bash
set -e -o pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo 'deleting IAM Roles and Policies'

ROLE_NAME='cnoe-external-dns'
POLICY_NAME='cnoe-external-dns'

aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}

aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}
aws iam delete-role --role-name ${ROLE_NAME}

kubectl delete -f argo-app.yaml
