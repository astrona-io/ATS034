#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-02-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
worker_name="$cluster-worker"

kubectl label node "$worker_name" sandbox=true --overwrite
kubectl apply -f "$solution_directory/runtimeclass-sandboxed.yaml"
kubectl apply -f "$solution_directory/pod-sandboxed-app.yaml"
kubectl -n tenant-b-034-030-02-01 wait --for=condition=Ready pod/sandboxed-app --timeout=180s
