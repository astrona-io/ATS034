#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-ats-034-playground-010-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-playground-010-03-control-plane"
worker_name="astro-ats-034-playground-010-03-worker"

kubectl apply -f "$solution_directory/namespaces-pod-security.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
