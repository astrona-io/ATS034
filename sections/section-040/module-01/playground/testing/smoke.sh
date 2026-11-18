#!/usr/bin/env bash
# Runs the commands that the module pages teach and checks each result:
# the sidecars exist, PERMISSIVE accepts plain text, STRICT rejects it, and
# an AuthorizationPolicy allows one ServiceAccount and denies another.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
probe_url=http://probe.starfleet.svc.cluster.local/

expect_reply() {
  local namespace=$1 pod=$2 output
  for attempt in $(seq 1 15); do
    if output=$(kubectl -n "$namespace" exec "$pod" -c client -- wget -q -T 3 -O- "$probe_url" 2>&1); then
      printf '%s/%s: %s\n' "$namespace" "$pod" "$output"
      grep -q '^version=v1' <<<"$output" && return 0
    fi
    sleep 2
  done
  printf 'FAIL: %s/%s got no version=v1 reply: %s\n' "$namespace" "$pod" "$output" >&2
  return 1
}

expect_failure() {
  local namespace=$1 pod=$2 pattern=$3 output
  for attempt in $(seq 1 15); do
    if ! output=$(kubectl -n "$namespace" exec "$pod" -c client -- wget -q -T 3 -O- "$probe_url" 2>&1); then
      printf '%s/%s: %s\n' "$namespace" "$pod" "$output"
      grep -q "$pattern" <<<"$output" && return 0
    fi
    sleep 2
  done
  printf 'FAIL: %s/%s did not fail with "%s": %s\n' "$namespace" "$pod" "$pattern" "$output" >&2
  return 1
}

echo "== sidecars and namespace label"
kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].spec.initContainers[*].name} {.items[0].spec.containers[*].name}{"\n"}' | tee /dev/stderr | grep -qw istio-proxy
kubectl get namespace starfleet --show-labels
kubectl -n istio-system get pods

echo "== PERMISSIVE (default): both clients get a reply"
expect_reply starfleet shuttle
expect_reply outpost drifter

echo "== STRICT for starfleet"
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
EOF
expect_reply starfleet shuttle
expect_failure outpost drifter 'reset'
kubectl -n starfleet get pods -l app=probe

echo "== AuthorizationPolicy allows only the bridge ServiceAccount"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bridge
  namespace: starfleet
---
apiVersion: v1
kind: Pod
metadata:
  name: bridge-client
  namespace: starfleet
spec:
  serviceAccountName: bridge
  containers:
  - name: client
    image: busybox:1.37.0
    command: ["sleep", "3600"]
EOF
kubectl -n starfleet wait --for=condition=Ready pod/bridge-client --timeout=120s
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-bridge
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/bridge"]
    to:
    - operation:
        methods: ["GET"]
EOF
expect_reply starfleet bridge-client
expect_failure starfleet shuttle '403'
echo "smoke test passed"
