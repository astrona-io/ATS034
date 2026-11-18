#!/usr/bin/env bash
# Installs Cilium 1.20.4 as the network plugin, with encryption off, then starts
# a server Pod on the worker node, a client Pod on the control-plane node and
# a node-tools Pod (tcpdump, ip) in the network namespace of each node.
# Cilium needs Docker or rootful Podman, because it mounts the BPF filesystem.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
playground_directory="$(cd "$(dirname "$0")/.." && pwd)"
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
kubectl apply -f "$playground_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/probe pod/shuttle --timeout=180s
kubectl -n node-tools rollout status daemonset/node-tools --timeout=180s
