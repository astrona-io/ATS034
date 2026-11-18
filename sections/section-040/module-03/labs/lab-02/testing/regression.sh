#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py wireguard-peers
sudo python3 /opt/astrona-live/check.py encrypted-traffic
export KUBECONFIG=/etc/training/kubeconfig
kubectl -n kube-system patch configmap cilium-config --type=merge -p '{"data":{"enable-wireguard":"false"}}'
set +e
output=$(sudo python3 /opt/astrona-live/check.py encrypted-traffic); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Enable Cilium WireGuard encryption' ]]
kubectl -n kube-system patch configmap cilium-config --type=merge -p '{"data":{"enable-wireguard":"true"}}'
