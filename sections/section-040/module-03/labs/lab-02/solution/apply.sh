#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG=/etc/training/kubeconfig
sudo helm --kubeconfig "$KUBECONFIG" upgrade cilium /etc/training/cilium-1.20.4.tgz --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard --wait --timeout=8m
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
sleep 10
