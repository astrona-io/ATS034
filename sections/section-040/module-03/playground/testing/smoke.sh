#!/usr/bin/env bash
# Runs the commands that the module pages teach and checks each result:
# no encryption at the start, WireGuard after a Helm upgrade, IPsec with a key
# Secret, and a key rotation to a higher SPI. The key is never printed.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

agent_pods() {
  kubectl -n kube-system get pods -l k8s-app=cilium -o name
}

expect_on_every_agent() {
  local pattern=$1 pod status
  for pod in $(agent_pods); do
    status=$(kubectl -n kube-system exec "$pod" -c cilium-agent -- cilium-dbg encrypt status)
    printf '%s\n%s\n' "$pod" "$status"
    grep -Eq "$pattern" <<<"$status" || { printf 'FAIL: %s does not match "%s"\n' "$pod" "$pattern" >&2; return 1; }
  done
}

expect_probe_reply() {
  local probe_ip output
  probe_ip=$(kubectl -n starfleet get pod probe -o jsonpath='{.status.podIP}')
  for attempt in $(seq 1 15); do
    if output=$(kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- "http://$probe_ip:8080/" 2>&1); then
      printf 'shuttle -> %s: %s\n' "$probe_ip" "$output"
      grep -q probe-reply <<<"$output" && return 0
    fi
    sleep 2
  done
  printf 'FAIL: shuttle got no probe-reply: %s\n' "$output" >&2
  return 1
}

count_spi_on_every_node() {
  local spi=$1 pod
  for pod in $(agent_pods); do
    kubectl -n kube-system exec "$pod" -c cilium-agent -- ip xfrm state | grep -o 'spi 0x[0-9a-f]*' | grep -qx "spi $spi" || return 1
  done
}

upgrade_encryption() {
  helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system \
    --reuse-values "$@" --wait --timeout 10m
  kubectl -n kube-system rollout restart daemonset/cilium
  kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
}

echo "== starting state"
kubectl get pods -A -o wide | grep -E 'starfleet|node-tools'
expect_on_every_agent 'Encryption:[[:space:]]*Disabled'
expect_probe_reply

echo "== WireGuard"
upgrade_encryption --set encryption.enabled=true --set encryption.type=wireguard
expect_on_every_agent 'Number of peers:[[:space:]]*1'
for pod in $(agent_pods); do
  kubectl -n kube-system exec "$pod" -c cilium-agent -- ip -d link show cilium_wg0 | head -1
done
expect_probe_reply

echo "== IPsec"
kubectl -n kube-system create secret generic cilium-ipsec-keys \
  --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
upgrade_encryption --set encryption.type=ipsec
expect_on_every_agent 'Encryption:[[:space:]]*IPsec'
expect_on_every_agent 'Errors:[[:space:]]*0'
count_spi_on_every_node 0x00000003
expect_probe_reply

echo "== key rotation to SPI 4"
kubectl -n kube-system patch secret cilium-ipsec-keys \
  -p "{\"stringData\":{\"keys\":\"4+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
rotated=no
for attempt in $(seq 1 48); do
  if count_spi_on_every_node 0x00000004; then rotated=yes; break; fi
  sleep 5
done
[ "$rotated" = yes ] || { echo 'FAIL: the agents did not load SPI 4 within 4 minutes' >&2; exit 1; }
expect_on_every_agent 'Errors:[[:space:]]*0'
expect_probe_reply
echo "smoke test passed"
