#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/admissionpolicy-require-tenant-node.yaml"
kubectl apply -f "$solution_directory/deployment-tenant-e-app.yaml"
kubectl -n tenant-e-034-030-03-03 rollout status deployment/tenant-e-app --timeout=180s
