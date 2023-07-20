#!/bin/bash
set -e -o pipefail

kubectl delete -f letsencrypt-prod.yaml
kubectl delete -f letsencrypt-staging.yaml

kubectl delete -f argo-app.yaml
