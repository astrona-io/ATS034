#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
current="$(kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1 | tr -d '+')"
next=$((current + 1))
kubectl -n kube-system patch secret cilium-ipsec-keys \
  -p "{\"stringData\":{\"keys\":\"${next}+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
# Each agent watches the key file and loads the new key after a random
# delay of up to 30 seconds; wait up to 4 minutes for both nodes.
spi="$(printf 'spi 0x%08x' "$next")"
for attempt in $(seq 1 48); do
  loaded=0
  for pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
    if kubectl -n kube-system exec "$pod" -c cilium-agent -- ip xfrm state | grep -q "$spi"; then
      loaded=$((loaded + 1))
    fi
  done
  [ "$loaded" -ge 2 ] && exit 0
  sleep 5
done
printf 'The agents did not load the key with SPI %s within 4 minutes\n' "$next" >&2
exit 1
