#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-03}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker_name="$cluster-worker"
kubectl label node "$worker_name" node-restriction.kubernetes.io/tenant=tenant-e --overwrite
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n tenant-e-034-030-03-03 rollout status deployment/tenant-e-app --timeout=180s
