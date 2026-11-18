#!/usr/bin/env bash
# Runs the commands that the module pages teach against this playground and
# fails when one of them does not give the result the page describes.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-030-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT

# Write the YAML block that follows "Save this as `<file>`" on a page.
save_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save this as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no YAML block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
  kubectl apply -f "$work_directory/$2"
}

expect() {
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

kubectl -n starfleet rollout status deployment/probe --timeout=180s

# Namespaces and RBAC
page=course-01-namespaces-and-rbac-as-a-tenant-boundary.md
save_from_page "$page" namespace-tenant-demo.yaml
save_from_page "$page" rbac-tenant-demo.yaml
expect 'tenant-user can create deployments in tenant-demo' "$(kubectl auth can-i create deployments -n tenant-demo --as=tenant-user)" yes
expect 'tenant-user cannot read secrets' "$(kubectl auth can-i get secrets -n tenant-demo --as=tenant-user || true)" no
expect 'tenant-user cannot write starfleet' "$(kubectl auth can-i create deployments -n starfleet --as=tenant-user || true)" no
expect 'tenant-user cannot list nodes' "$(kubectl auth can-i list nodes --as=tenant-user 2>&1 || true)" no
expect 'nodes are cluster-scoped' "$(kubectl api-resources --namespaced=false)" storageclasses

# ResourceQuota and LimitRange
page=course-02-resource-isolation-with-resourcequota-and-limitrange.md
save_from_page "$page" namespace-quota-demo.yaml
save_from_page "$page" deployment-burst.yaml
for attempt in $(seq 1 30); do
  ready="$(kubectl -n quota-demo get deployment burst -o jsonpath='{.status.readyReplicas}')"
  [[ "$ready" == 2 ]] && break
  sleep 2
done
expect 'quota stops the third Pod' "$(kubectl -n quota-demo get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message)" 'exceeded quota: compute-budget'
expect 'two ready replicas' "$(kubectl -n quota-demo get deployment burst -o jsonpath='{.status.readyReplicas}')" 2
resources="$(kubectl -n quota-demo get pods -l app=burst -o jsonpath='{.items[0].spec.containers[0].resources}')"
expect 'LimitRange default limit' "$resources" '"limits":{"memory":"64Mi"}'
expect 'LimitRange default request' "$resources" '"requests":{"memory":"32Mi"}'

# NetworkPolicy and token mount
page=course-03-network-isolation-and-token-minimization.md
save_from_page "$page" pods-network-demo.yaml
kubectl -n network-demo wait --for=condition=Ready pod/token-default pod/token-off --timeout=120s
PROBE_IP=$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')
expect 'request crosses namespaces without a policy' "$(kubectl -n network-demo exec token-off -- wget -q -T 3 -O- "http://$PROBE_IP/")" version=v1
save_from_page "$page" networkpolicy-default-deny.yaml
sleep 3
blocked="$(kubectl -n network-demo exec token-off -- wget -q -T 3 -O- "http://$PROBE_IP/" 2>&1 || true)"
expect 'default deny blocks the request' "$blocked" 'timed out'
save_from_page "$page" networkpolicy-allow-probe.yaml
allowed=''
for attempt in $(seq 1 10); do
  allowed="$(kubectl -n network-demo exec token-off -- wget -q -T 3 -O- "http://$PROBE_IP/" 2>&1 || true)"
  [[ "$allowed" == *version=v1* ]] && break
  sleep 2
done
expect 'allow-probe opens one path' "$allowed" version=v1
expect 'default Pod has a token' "$(kubectl -n network-demo exec token-default -- ls /var/run/secrets/kubernetes.io/serviceaccount)" token
expect 'token-off has no token' "$(kubectl -n network-demo exec token-off -- ls /var/run/secrets/kubernetes.io/serviceaccount 2>&1 || true)" 'No such file or directory'

# RuntimeClass without a handler
page=course-04-sandboxed-containers-with-runtimeclass.md
save_from_page "$page" runtimeclass-gvisor.yaml
expect 'RuntimeClass gvisor uses runsc' "$(kubectl get runtimeclass gvisor -o jsonpath='{.handler}')" runsc
save_from_page "$page" pod-sandboxed.yaml
events=''
for attempt in $(seq 1 30); do
  events="$(kubectl -n default get events --field-selector involvedObject.name=sandboxed -o custom-columns=REASON:.reason,MESSAGE:.message)"
  [[ "$events" == *runsc* ]] && break
  sleep 2
done
printf '%s\n' "$events" | head -3
expect 'the Pod cannot start without the runsc handler' "$events" 'FailedCreatePodSandBox'
expect 'the event names the handler' "$events" runsc
expect 'the Pod stays in ContainerCreating' "$(kubectl get pod sandboxed)" ContainerCreating
kubectl delete pod sandboxed --wait=false
printf 'PASS: every page command gave the expected result\n'
