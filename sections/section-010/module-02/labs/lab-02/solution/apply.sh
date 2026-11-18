#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
# The security settings of a container cannot change in place, so the Pod is replaced.
kubectl -n starfleet-034-010-02-02 delete pod courier --ignore-not-found --wait=true --timeout=120s
kubectl apply -f "$solution_directory/pod-courier.yaml"
kubectl -n starfleet-034-010-02-02 wait --for=condition=Ready pod/courier --timeout=120s
