#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

kubectl delete -f letsencrypt-prod.yaml
kubectl delete -f letsencrypt-staging.yaml

kubectl delete -f argo-app.yaml
kubectl delete -f ${REPO_ROOT}/packages/cert-manager/base/crds.yaml
kubectl delete namespace cert-manager

