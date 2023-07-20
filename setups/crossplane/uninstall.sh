#!/bin/bash

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo 'deleting IAM Roles and Policies'

aws iam detach-role-policy --role-name crossplane-aws-provider-role --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CrossplaneProviderAWS

aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CrossplaneProviderAWS
aws iam delete-role --role-name crossplane-aws-provider-role

kubectl delete -f argo-app.yaml
