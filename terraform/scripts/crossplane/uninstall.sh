#!/bin/bash
set -e -o pipefail

while true; do
  provider_count=$(kubectl get --ignore-not-found=true Provider.pkg.crossplane.io | wc -l)
  if [ "$provider_count" -eq 0 ]; then
    exit 0
  fi
  echo "waiting for $provider_count providers to be deleted"
  sleep 10
done
