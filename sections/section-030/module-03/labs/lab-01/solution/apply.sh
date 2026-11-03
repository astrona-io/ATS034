#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-lab-030-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-lab-030-03-01-control-plane"
worker_name="astro-ats-034-lab-030-03-01-worker"

kubectl label node "$worker_name" tenant=tenant-c --overwrite
kubectl taint node "$worker_name" tenant=tenant-c:NoSchedule --overwrite
kubectl apply -f "$solution_directory/deployment-tenant-c-app.yaml"
kubectl -n tenant-c rollout status deployment/tenant-c-app --timeout=180s
