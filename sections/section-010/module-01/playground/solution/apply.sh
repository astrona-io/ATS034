#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-010-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-playground-010-01-control-plane"
worker_name="astro-ats-034-playground-010-01-worker"

kubectl apply -f "$solution_directory/namespace-restricted.yaml"
kubectl -n restricted wait --for=condition=Ready pod/restricted-reader --timeout=180s
