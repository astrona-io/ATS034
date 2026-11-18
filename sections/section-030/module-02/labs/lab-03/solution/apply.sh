#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-030-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/admissionpolicy-require-sandbox.yaml"
kubectl -n untrusted-034-030-02-03 delete pod job-runner --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-job-runner.yaml"
kubectl -n untrusted-034-030-02-03 wait --for=condition=Ready pod/job-runner --timeout=180s
