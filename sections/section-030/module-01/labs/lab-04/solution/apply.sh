#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-030-01-04}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/runtimeclass-gvisor.yaml"
kubectl apply -f "$solution_directory/pod-sandboxed.yaml"
kubectl -n tenant-a-034-030-01-04 wait --for=condition=Ready pod/sandboxed --timeout=180s
