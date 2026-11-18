#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-034-020-01-02"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/file-reader pod/env-reader --timeout=180s
# Record the UID of each starting Pod. The graders compare against it to tell
# the original Pod from a recreated one.
file_reader_uid="$(kubectl -n "$namespace" get pod file-reader -o jsonpath='{.metadata.uid}')"
env_reader_uid="$(kubectl -n "$namespace" get pod env-reader -o jsonpath='{.metadata.uid}')"
kubectl -n "$namespace" create configmap rotation-start \
  --from-literal=file-reader-uid="$file_reader_uid" \
  --from-literal=env-reader-uid="$env_reader_uid" \
  --dry-run=client -o yaml | kubectl apply -f -
