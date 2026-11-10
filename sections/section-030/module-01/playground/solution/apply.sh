#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-030-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-playground-030-01}"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

kubectl apply -f "$solution_directory/namespace-tenant-a.yaml"
kubectl -n tenant-a wait --for=condition=Ready pod/tenant-reader --timeout=180s
