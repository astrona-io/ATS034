#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/networkpolicy-tenant-a.yaml"
# A Pod receives its token at creation, so recreate it after the ServiceAccount change.
kubectl -n tenant-a-034-030-01-03 delete pod worker --wait=true
kubectl apply -f "$solution_directory/pod-worker.yaml"
kubectl -n tenant-a-034-030-01-03 wait --for=condition=Ready pod/worker --timeout=120s
