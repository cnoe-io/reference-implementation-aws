#!/bin/bash
set -e -o pipefail

read -p "Enter your Route53 hosted zone ID: " HOSTEDZONE_ID
read -p "Enter your AWS Region: " REGION
read -p "Enter your EKS Cluster Name: " CLUSTER_NAME

if [[ -z "${GITHUB_URL}" ]]; then
    read -p "Enter GitHub repository URL e.g. https://github.com/cnoe-io/reference-implementation-aws : " GITHUB_URL
    export GITHUB_URL
fi

export HOSTEDZONE_ID
export REGION
export CLUSTER_NAME

export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text --region $REGION | sed -e "s/^https:\/\///")
export DOMAIN_NAME=$(aws route53 get-hosted-zone --id ${HOSTEDZONE_ID} | jq -r '.HostedZone.Name')

envsubst < trust-policy.json > trust-policy-to-be-applied.json

envsubst < external-dns-policy.json > external-dns-policy-to-be-applied.json

POLICY_OUTPUT=$(aws iam create-policy \
    --policy-name cnoeExternalDNS \
    --policy-document file://external-dns-policy-to-be-applied.json)

POLICY_ARN=$(echo $POLICY_OUTPUT | jq -r '.Policy.Arn')

ROLE_OUTPUT=$(aws iam create-role --role-name cnoe-external-dns --assume-role-policy-document file://trust-policy-to-be-applied.json --description "For use with AWS Load Balancer Controller")

export ROLE_ARN=$(echo $ROLE_OUTPUT | jq -r '.Role.Arn')

aws iam attach-role-policy --role-name cnoe-external-dns --policy-arn ${POLICY_ARN}

envsubst '$GITHUB_URL $ROLE_ARN $DOMAIN_NAME'  < argo-app.yaml | kubectl apply -f -

rm trust-policy-to-be-applied.json
rm external-dns-policy-to-be-applied.json