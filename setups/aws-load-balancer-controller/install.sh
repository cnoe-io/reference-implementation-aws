#!/bin/bash
set -e -o pipefail

if [[ -z "${CLUSTER_NAME}" ]]; then
    read -p "Enter your EKS Cluster Name: " CLUSTER_NAME
    export CLUSTER_NAME
fi

if [[ -z "${REGION}" ]]; then
    read -p "Enter your AWS Region: " REGION
    export REGION
fi

export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text --region $REGION | sed -e "s/^https:\/\///")
ROLE_NAME='cnoe-aws-load-balancer-controller'
POLICY_NAME='cnoe-aws-load-balancer-controller'

envsubst < trust-policy.json > trust-policy-to-be-applied.json

POLICY_OUTPUT=$(aws iam create-policy \
    --policy-name ${POLICY_NAME} \
    --policy-document file://aws-load-balancer-controller-iam-policy.json)

POLICY_ARN=$(echo $POLICY_OUTPUT | jq -r '.Policy.Arn')

ROLE_OUTPUT=$(aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://trust-policy-to-be-applied.json --description "For use with AWS Load Balancer Controller")

export ROLE_ARN=$(echo $ROLE_OUTPUT | jq -r '.Role.Arn')

aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN}

envsubst < argo-app.yaml | kubectl apply -f -
rm trust-policy-to-be-applied.json
kubectl wait --for=jsonpath=.status.health.status=Healthy  --timeout=300s -f argo-app.yaml
