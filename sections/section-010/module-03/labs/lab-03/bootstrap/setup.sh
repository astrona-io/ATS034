#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# The hostPath volume breaks Baseline, so the ReplicaSet records FailedCreate.
for attempt in $(seq 1 30); do
  if kubectl -n node-agents-034-010-03-03 get events --field-selector reason=FailedCreate -o name | grep -q .; then
    exit 0
  fi
  sleep 2
done
printf 'The log-agent ReplicaSet did not report FailedCreate\n' >&2
exit 1
