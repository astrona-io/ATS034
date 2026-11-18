#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-02}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
worker_name="$cluster-worker"

kubectl label node "$worker_name" node-restriction.kubernetes.io/tenant=tenant-d --overwrite
kubectl apply -f "$solution_directory/deployment-tenant-d-app.yaml"
kubectl -n tenant-d-034-030-03-02 rollout status deployment/tenant-d-app --timeout=180s
kubectl label node "$worker_name" tenant-
