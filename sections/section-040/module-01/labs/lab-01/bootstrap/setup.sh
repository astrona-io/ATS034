#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-040-01-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-034-040-01-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-034-040-01-01 wait --for=condition=Ready pod/drifter --timeout=120s
helm upgrade --install istio-base base --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istiod --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --wait --timeout 10m
kubectl label namespace starfleet-034-040-01-01 istio-injection=enabled --overwrite
kubectl -n starfleet-034-040-01-01 rollout restart deployment/probe
kubectl -n starfleet-034-040-01-01 delete pod shuttle --wait=true
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-040-01-01 rollout status deployment/probe --timeout=300s
kubectl -n starfleet-034-040-01-01 wait --for=condition=Ready pod/shuttle --timeout=300s
