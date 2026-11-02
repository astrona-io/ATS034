#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-040-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="astro-ats-034-playground-040-01-control-plane"
worker_name="astro-ats-034-playground-040-01-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
helm upgrade --install istio-base base --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istiod --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --wait --timeout 10m
kubectl label namespace starfleet istio-injection=enabled --overwrite
kubectl -n starfleet rollout restart deployment/probe
kubectl -n starfleet delete pod shuttle --wait=true
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=300s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=300s
