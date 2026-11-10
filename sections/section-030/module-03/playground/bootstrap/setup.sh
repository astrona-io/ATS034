#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-030-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-playground-030-03}"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/tenant-c --timeout=60s
