#!/usr/bin/env bash
# Runs the commands that the module pages teach against this playground and
# fails when one of them does not give the result the page describes.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-030-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
worker_name=astro-ats-034-playground-030-03-worker

# Write the YAML block that follows "Save this as `<file>`" (or "as `<file>`") on a page.
save_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
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

# Taints and tolerations
page=course-01-dedicated-nodes-with-taints-and-tolerations.md
kubectl label node "$worker_name" tenant=tenant-c
kubectl taint node "$worker_name" tenant=tenant-c:NoSchedule
save_from_page "$page" deployment-tenant-c-app.yaml
kubectl -n tenant-c rollout status deployment/tenant-c-app --timeout=120s
expect 'tenant Pod runs on the worker' "$(kubectl -n tenant-c get pods -l app=tenant-c-app -o wide)" "$worker_name"
save_from_page "$page" pod-stray.yaml
events=''
for attempt in $(seq 1 20); do
  events="$(kubectl -n tenant-c describe pod stray)"
  [[ "$events" == *FailedScheduling* ]] && break
  sleep 2
done
printf '%s\n' "$events" | grep FailedScheduling
expect 'stray Pod stays Pending' "$(kubectl -n tenant-c get pod stray -o jsonpath='{.status.phase}')" Pending
expect 'scheduler reports the taints of both nodes' "$events" '0/2 nodes are available: 2 node(s) had untolerated taint(s)'

# NodeRestriction
page=course-02-node-labels-you-can-trust.md
flags="$(kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}')"
expect 'API server enables NodeRestriction' "$flags" NodeRestriction
expect 'API server uses Node authorization' "$flags" 'Node,RBAC'
kubectl label node "$worker_name" node-restriction.kubernetes.io/tenant=tenant-c
expect 'protected label is on the worker' "$(kubectl get node "$worker_name" --show-labels)" node-restriction.kubernetes.io/tenant=tenant-c
expect 'tenant user cannot patch nodes' "$(kubectl auth can-i patch nodes --as=tenant-c-user 2>&1 || true)" no

# ValidatingAdmissionPolicy
page=course-03-forcing-placement-at-admission.md
save_from_page "$page" policy-require-tenant-node.yaml
save_from_page "$page" binding-require-tenant-node.yaml
denied=''
for attempt in $(seq 1 10); do
  denied="$(kubectl -n tenant-c run no-selector --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -- sleep 60 2>&1 || true)"
  [[ "$denied" == *denied* ]] && break
  sleep 2
done
printf '%s\n' "$denied"
expect 'policy rejects a Pod without the selector' "$denied" 'Pods in tenant-c must select tenant=tenant-c'
allowed="$(kubectl -n tenant-c run with-selector --image=docker.io/library/busybox:1.37.0 --restart=Never --overrides='{"spec":{"nodeSelector":{"tenant":"tenant-c"}}}' --dry-run=server -- sleep 60)"
expect 'policy admits a Pod with the selector' "$allowed" 'created (server dry run)'

# Shared node
expect 'system Pods share the worker' "$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$worker_name)" kube-proxy
printf 'PASS: every page command gave the expected result\n'
