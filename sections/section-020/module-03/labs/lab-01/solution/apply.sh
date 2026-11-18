#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl -n starfleet-034-020-03-01 create secret generic scout-credentials --from-literal=token=disposable-scout
kubectl apply -f "$lab_directory/solution/deployment-scout.yaml"
kubectl -n starfleet-034-020-03-01 rollout status deployment/scout --timeout=180s
kubectl -n starfleet-034-020-03-01 delete configmap legacy-settings
