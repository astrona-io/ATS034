#!/usr/bin/env bash
# Installs Istio 1.30.5 with Helm, then creates the namespaces and workloads.
# The workloads are created after istiod runs, so the sidecar injector adds
# the istio-proxy sidecar to every pod in the starfleet namespace.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
playground_directory="$(cd "$(dirname "$0")/.." && pwd)"
helm upgrade --install istio-base base --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istiod --repo https://istio-release.storage.googleapis.com/charts --version 1.30.5 -n istio-system --wait --timeout 10m
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
# The sidecar injector webhook can refuse calls for a few seconds after
# istiod reports ready, so the apply is retried for up to 2.5 minutes.
for attempt in $(seq 1 30); do
  kubectl apply -f "$playground_directory/bootstrap/manifests/start.yaml" && break
  [ "$attempt" -lt 30 ] || exit 1
  sleep 5
done
kubectl -n starfleet rollout status deployment/probe --timeout=300s
kubectl -n starfleet rollout status deployment/legacy --timeout=300s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=300s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=300s
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.initContainers[*].name}' | grep -qw istio-proxy || { echo "shuttle has no istio-proxy sidecar" >&2; exit 1; }
kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].spec.initContainers[*].name}' | grep -qw istio-proxy || { echo "probe has no istio-proxy sidecar" >&2; exit 1; }
kubectl -n starfleet get pod -l app=legacy -o jsonpath='{.items[0].spec.initContainers[*].name}' | grep -qw istio-proxy || { echo "legacy has no istio-proxy sidecar" >&2; exit 1; }
