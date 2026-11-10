#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-capstone-040}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-capstone-040}"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle pod/tender --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
helm upgrade --install istio-base base --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istiod --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --wait --timeout 10m
kubectl label namespace starfleet istio-injection=enabled --overwrite
kubectl -n starfleet rollout restart deployment/probe
kubectl -n starfleet delete pod shuttle tender --wait=true
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=300s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle pod/tender --timeout=300s
