#!/bin/bash
set -e -o pipefail

kubectl delete -f argo-app.yaml
