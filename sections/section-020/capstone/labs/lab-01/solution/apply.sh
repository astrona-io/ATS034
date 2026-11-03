#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-capstone-020" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-034-capstone-020-control-plane"

kubectl apply -f "$solution_directory/secret-probe-credentials.yaml"
kubectl apply -f "$solution_directory/secret-registry-pull.yaml"
kubectl apply -f "$solution_directory/serviceaccount-reader.yaml"
kubectl apply -f "$solution_directory/role-secret-reader.yaml"
kubectl apply -f "$solution_directory/pod-credential-reader.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/credential-reader --timeout=180s
kubectl -n starfleet delete configmap legacy-credentials --ignore-not-found
