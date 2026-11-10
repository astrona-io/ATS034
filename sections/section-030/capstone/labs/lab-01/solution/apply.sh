#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-capstone-030}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-capstone-030}"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

kubectl apply -f "$solution_directory/namespace-untrusted.yaml"
kubectl label node "$worker_name" isolation=untrusted --overwrite
kubectl taint node "$worker_name" isolation=untrusted:NoSchedule --overwrite
kubectl apply -f "$solution_directory/runtimeclass-sandboxed.yaml"
kubectl apply -f "$solution_directory/networkpolicy-untrusted-isolation.yaml"
kubectl apply -f "$solution_directory/admissionpolicy-require-sandbox.yaml"
kubectl -n untrusted wait --for=jsonpath='{.status.phase}'=Active namespace/untrusted --timeout=60s || true
sleep 10
kubectl apply -f "$solution_directory/pod-job-runner.yaml"
kubectl -n untrusted wait --for=condition=Ready pod/job-runner --timeout=180s
