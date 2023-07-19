#!/bin/bash
set -e -o pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws iam detach-role-policy --role-name aws-load-balancer-controller --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy

aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
aws iam delete-role --role-name aws-load-balancer-controller

kubectl delete -f argo-app.yaml
