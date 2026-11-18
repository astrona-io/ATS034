#!/usr/bin/env bash
# Installs Cilium 1.20.4 as the network plugin of the kind cluster, then
# starts the probe server pod on the worker node and the shuttle client pod
# on the control-plane node, so that their traffic crosses between nodes.
# Cilium needs a rootful container engine: it mounts the BPF filesystem.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-03-01}"
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
kubectl -n starfleet-034-040-03-01 wait --for=condition=Ready pod/probe pod/shuttle --timeout=300s
