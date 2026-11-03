#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-030-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="astro-ats-034-playground-030-03-control-plane"
worker_name="astro-ats-034-playground-030-03-worker"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/tenant-c --timeout=60s
