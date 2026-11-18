#!/usr/bin/env bash
# Runs the commands that the module pages teach and checks each result:
# precedence between a mesh and a namespace policy, the migration to STRICT
# with one workload exception, the workload certificate, the proxy
# statistics, and a DestinationRule that breaks mTLS on the client side.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-040-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

expect_reply() {
  local namespace=$1 pod=$2 url=$3 pattern=$4 output
  for attempt in $(seq 1 15); do
    if output=$(kubectl -n "$namespace" exec "$pod" -c client -- wget -q -T 3 -O- "$url" 2>&1); then
      printf '%s/%s -> %s: %s\n' "$namespace" "$pod" "$url" "$output"
      grep -q "$pattern" <<<"$output" && return 0
    fi
    sleep 2
  done
  printf 'FAIL: %s/%s -> %s got no "%s" reply: %s\n' "$namespace" "$pod" "$url" "$pattern" "$output" >&2
  return 1
}

expect_failure() {
  local namespace=$1 pod=$2 url=$3 output
  for attempt in $(seq 1 15); do
    if ! output=$(kubectl -n "$namespace" exec "$pod" -c client -- wget -T 3 -O- "$url" 2>&1); then
      printf '%s/%s -> %s failed: %s\n' "$namespace" "$pod" "$url" "$output"
      return 0
    fi
    sleep 2
  done
  printf 'FAIL: %s/%s -> %s still gets a reply: %s\n' "$namespace" "$pod" "$url" "$output" >&2
  return 1
}

probe_url=http://probe.starfleet.svc.cluster.local/
legacy_url=http://legacy.starfleet.svc.cluster.local/

echo "== precedence"
kubectl get peerauthentication -A
expect_reply outpost drifter "$probe_url" '^version=v1'
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
expect_failure outpost drifter "$probe_url"
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-permissive
  namespace: starfleet
spec:
  mtls:
    mode: PERMISSIVE
EOF
expect_reply outpost drifter "$probe_url" '^version=v1'
kubectl -n starfleet delete peerauthentication namespace-permissive
kubectl -n istio-system delete peerauthentication default

echo "== migration to STRICT with one exception"
kubectl -n starfleet get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[*].name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
expect_reply outpost drifter "$probe_url" '^version=v1'
expect_reply outpost drifter "$legacy_url" '^version=legacy'
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
expect_failure outpost drifter "$probe_url"
expect_failure outpost drifter "$legacy_url"
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: legacy-permissive
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: legacy
  mtls:
    mode: PERMISSIVE
EOF
expect_reply outpost drifter "$legacy_url" '^version=legacy'
expect_failure outpost drifter "$probe_url"
expect_reply starfleet shuttle "$probe_url" '^version=v1'

echo "== certificate and identity"
kubectl -n starfleet exec shuttle -c istio-proxy -- pilot-agent request GET certs | grep -E 'spiffe://cluster.local/ns/starfleet/sa/default'
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.serviceAccountName}{"\n"}'
kubectl -n istio-system get secret
kubectl -n starfleet get configmap istio-ca-root-cert

echo "== proxy statistics"
for request in 1 2 3 4 5 6; do
  kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O /dev/null http://probe/
done
for probe_pod in $(kubectl -n starfleet get pods -l app=probe -o name); do
  echo "-- $probe_pod"
  kubectl -n starfleet exec "$probe_pod" -c istio-proxy -- pilot-agent request GET stats/prometheus \
    | grep '^istio_requests_total' | grep 'reporter="destination"' \
    | grep -o 'source_workload="[^"]*"\|connection_security_policy="[^"]*"\|response_code="[^"]*"' \
    | paste - - - | sort | uniq -c
done | tee /dev/stderr | grep 'connection_security_policy="mutual_tls"' >/dev/null
kubectl -n starfleet logs deploy/probe -c istio-proxy --tail=5

echo "== DestinationRule with tls.mode DISABLE"
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: probe-disable-tls
  namespace: starfleet
spec:
  host: probe.starfleet.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
EOF
expect_failure starfleet shuttle "$probe_url"
kubectl -n starfleet delete destinationrule probe-disable-tls
expect_reply starfleet shuttle "$probe_url" '^version=v1'
echo "smoke test passed"
