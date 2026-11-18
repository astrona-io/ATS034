#!/usr/bin/env bash
# Installs Istio 1.30.5 with Helm, then creates the namespaces and workloads.
# The workloads are created after istiod runs, so the sidecar injector adds
# the istio-proxy sidecar when each pod is created.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
helm upgrade --install istio-base base --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istiod --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --wait --timeout 10m
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-040-02-01 rollout status deployment/probe --timeout=300s
kubectl -n depot-034-040-02-01 rollout status deployment/cargo --timeout=300s
kubectl -n starfleet-034-040-02-01 wait --for=condition=Ready pod/shuttle --timeout=300s
kubectl -n outpost-034-040-02-01 wait --for=condition=Ready pod/drifter --timeout=300s
kubectl -n starfleet-034-040-02-01 get pod shuttle -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' | grep -qw istio-proxy || { echo "pod shuttle has no istio-proxy sidecar" >&2; exit 1; }
