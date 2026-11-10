#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-playground-040-02-control-plane"
worker_name="astro-ats-034-playground-040-02-worker"

kubectl apply -f "$solution_directory/peerauthentication-namespace-strict.yaml"
kubectl apply -f "$solution_directory/peerauthentication-legacy-permissive.yaml"
