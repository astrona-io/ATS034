#!/usr/bin/env bash
# Installs Cilium 1.20.4 as the network plugin of the kind cluster and starts
# the probe server pod on the worker node and the shuttle client pod on the
# control-plane node. Then it turns WireGuard on in the Helm release, but
# restarts only the Cilium agent on the control-plane node, so the agent on
# the worker node keeps running with encryption disabled.
# Cilium needs a rootful container engine: it mounts the BPF filesystem.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
helm upgrade --install cilium cilium --repo https://helm.cilium.io --version 1.20.4 \
  --namespace kube-system \
  --set operator.replicas=1 \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=false \
  --set image.useDigest=false \
  --set operator.image.useDigest=false \
  --set envoy.image.useDigest=false \
  --set encryption.enabled=false \
  --wait --timeout 10m
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl wait nodes --all --for=condition=Ready --timeout=300s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-040-03-03 wait --for=condition=Ready pod/probe pod/shuttle --timeout=300s

# Turn WireGuard on. The chart changes only the ConfigMap cilium-config, so
# the running agents keep their old settings until they restart.
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system \
  --reuse-values --set encryption.enabled=true --set encryption.type=wireguard --wait --timeout 10m

# Restart only the agent on the control-plane node.
control_plane="$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')"
kubectl -n kube-system delete pod -l k8s-app=cilium --field-selector "spec.nodeName=$control_plane" --wait=true
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s

# Wait, with a timeout, until the new agent reports WireGuard. Refuse to hand
# out the lab unless exactly one agent reports WireGuard and one is disabled.
for attempt in $(seq 1 60); do
  wireguard=0
  disabled=0
  for agent_pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
    status="$(kubectl -n kube-system exec "$agent_pod" -c cilium-agent -- cilium-dbg encrypt status 2>/dev/null || true)"
    if grep -q 'Encryption: *Wireguard' <<<"$status"; then
      wireguard=$((wireguard + 1))
    elif grep -q 'Encryption: *Disabled' <<<"$status"; then
      disabled=$((disabled + 1))
    fi
  done
  if [[ "$wireguard" -eq 1 && "$disabled" -eq 1 ]]; then
    exit 0
  fi
  sleep 5
done
printf 'The starting state did not settle: %s agent(s) report WireGuard, %s report Disabled\n' "$wireguard" "$disabled" >&2
exit 1
