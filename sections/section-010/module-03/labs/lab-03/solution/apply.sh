#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl label --overwrite namespace node-agents-034-010-03-03 \
  pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/enforce-version=v1.35 \
  pod-security.kubernetes.io/warn=baseline pod-security.kubernetes.io/warn-version=v1.35 \
  pod-security.kubernetes.io/audit=baseline pod-security.kubernetes.io/audit-version=v1.35
# The ReplicaSet controller retries with a growing delay; a restart creates the Pod now.
kubectl -n node-agents-034-010-03-03 rollout restart deployment/log-agent
kubectl -n node-agents-034-010-03-03 rollout status deployment/log-agent --timeout=180s
kubectl delete clusterrolebinding deployer-namespace-labeler-034-010-03-03
