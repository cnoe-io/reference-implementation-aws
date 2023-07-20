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

trap '{
    rm *to-be-applied.json || true
}' EXIT


export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text --region $REGION | sed -e "s/^https:\/\///")

envsubst < trust-policy.json > trust-policy-to-be-applied.json
envsubst < crossplane-aws-provider-iam-policy.json > crossplane-aws-provider-iam-policy-to-be-applied.json

echo 'creating AWS IAM policies and roles'
ROLE_NAME='cnoe-crossplane-provider-aws'
POLICY_NAME='cnoe-crossplane-provider-aws'

POLICY_OUTPUT=$(aws iam create-policy \
    --policy-name ${POLICY_NAME} \
    --policy-document file://crossplane-aws-provider-iam-policy-to-be-applied.json)

POLICY_ARN=$(echo $POLICY_OUTPUT | jq -r '.Policy.Arn')

ROLE_OUTPUT=$(aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document file://trust-policy-to-be-applied.json --description "For use Crossplane AWS providers")

export ROLE_ARN=$(echo $ROLE_OUTPUT | jq -r '.Role.Arn')

aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN}

echo 'creating Crossplane in your cluster...'
envsubst '$GITHUB_URL' < argo-app.yaml | kubectl apply -f -
