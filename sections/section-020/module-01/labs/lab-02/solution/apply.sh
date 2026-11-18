#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace="starfleet-034-020-01-02"

kubectl apply -f "$solution_directory/secret-practice-token.yaml"

# The kubelet refreshes the Secret volume of the running Pod on its next sync.
# Wait for it, at most three minutes.
for attempt in $(seq 1 36); do
  if [[ "$(kubectl -n "$namespace" exec file-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo new || echo old')" == new ]]; then
    break
  fi
  sleep 5
done

# An environment variable is read only when the container starts.
kubectl -n "$namespace" delete pod env-reader --wait=true
kubectl apply -f "$solution_directory/pod-env-reader.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/env-reader --timeout=180s
