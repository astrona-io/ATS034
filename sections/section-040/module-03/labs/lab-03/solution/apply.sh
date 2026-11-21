#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# Find the node whose Cilium agent still reports Encryption: Disabled.
stale_node=""
for agent_pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
  if kubectl -n kube-system exec "$agent_pod" -c cilium-agent -- cilium-dbg encrypt status | grep -q 'Encryption: *Disabled'; then
    stale_node="$(kubectl -n kube-system get "$agent_pod" -o jsonpath='{.spec.nodeName}')"
  fi
done
if [[ -z "$stale_node" ]]; then
  printf 'No Cilium agent reports Encryption: Disabled\n' >&2
  exit 1
fi
kubectl -n starfleet-034-040-03-03 create configmap encryption-diagnosis \
  --from-literal=node="$stale_node" --dry-run=client -o yaml | kubectl apply -f -
# Restart every agent, so each one loads the WireGuard setting.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
