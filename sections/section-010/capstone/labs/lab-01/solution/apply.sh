#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-capstone-010}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/deployment-probe.yaml" -f "$solution_directory/deployment-scout.yaml"
kubectl apply -f "$solution_directory/namespaces-pod-security.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n dock rollout status deployment/scout --timeout=180s
