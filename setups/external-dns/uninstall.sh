#!/bin/bash
set -e -o pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo 'deleting IAM Roles and Policies'

aws iam detach-role-policy --role-name cnoe-external-dns --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/cnoeExternalDNS

aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/cnoeExternalDNS
aws iam delete-role --role-name cnoe-external-dns

kubectl delete -f argo-app.yaml
