#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-02}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker_name="$cluster-worker"
# A plain label that the kubelet of the worker could change on its own node.
kubectl label node "$worker_name" tenant=tenant-d --overwrite
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n tenant-d-034-030-03-02 rollout status deployment/tenant-d-app --timeout=180s
