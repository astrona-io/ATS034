#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-lab-030-02-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-lab-030-02-01-control-plane"
worker_name="astro-ats-034-lab-030-02-01-worker"

kubectl label node "$worker_name" sandbox=true --overwrite
kubectl apply -f "$solution_directory/runtimeclass-sandboxed.yaml"
kubectl apply -f "$solution_directory/pod-sandboxed-app.yaml"
kubectl -n tenant-b wait --for=condition=Ready pod/sandboxed-app --timeout=180s
