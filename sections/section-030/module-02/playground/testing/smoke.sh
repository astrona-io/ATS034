#!/usr/bin/env bash
# Runs the commands that the module pages teach inside the playground VM and
# fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user.
set -euo pipefail
cluster_name=astro-ats-034-playground-030-02
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster_name}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
node_name="$cluster_name"
busybox=docker.io/library/busybox:1.37.0

# Write the YAML block that follows "Save this as `<file>`" (or "as `<file>`") on a page.
save_yaml_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no YAML block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_yaml_from_page "$1" "$2"
  kubectl apply -f "$work_directory/$2"
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Wait until the events of a Pod contain a reason, at most about 90 seconds.
wait_for_event() {
  local pod="$1" reason="$2" events=''
  for attempt in $(seq 1 45); do
    events="$(kubectl -n tenant-b get events --field-selector "involvedObject.name=$pod" 2>&1)"
    [[ "$events" == *"$reason"* ]] && break
    sleep 2
  done
  printf '%s\n' "$events"
}

# Playground guide
expect 'kubectl uses the playground context' "$(kubectl config current-context)" "kubernetes-admin@$cluster_name"
expect 'namespace tenant-b exists' "$(kubectl get namespace tenant-b -o jsonpath='{.status.phase}')" Active
expect 'tenant-b starts empty' "$(kubectl -n tenant-b get pods 2>&1)" 'No resources found'
handlers="$(sudo crictl info | jq -r '.config.containerd.runtimes | keys[]')"
expect 'containerd loaded the runc handler' "$handlers" runc
expect 'containerd loaded the runsc handler' "$handlers" runsc
expect 'no RuntimeClass at the start' "$(kubectl get runtimeclass 2>&1)" 'No resources found'

# The runtime handler chain
page=course-01-the-runtime-handler-chain.md
expect 'node runs containerd 2.2.1' "$(kubectl get nodes -o wide)" 'containerd://2.2.1'
config_lines="$(sudo grep -n "runtimes\.\|runtime_type" /etc/containerd/config.toml)"
printf '%s\n' "$config_lines"
expect 'config file registers runc' "$config_lines" "[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]"
expect 'runc uses the runc shim' "$config_lines" "runtime_type = 'io.containerd.runc.v2'"
expect 'config file registers runsc' "$config_lines" "[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]"
expect 'runsc uses the runsc shim' "$config_lines" 'runtime_type = "io.containerd.runsc.v1"'
save_from_page "$page" runtimeclass-gvisor.yaml
save_from_page "$page" pod-gvisor-check.yaml
kubectl -n tenant-b wait --for=condition=Ready pod/gvisor-check --timeout=180s
expect 'containerd started gvisor-check with runsc' "$(sudo crictl pods --namespace tenant-b --name gvisor-check)" runsc
missing="$(kubectl -n tenant-b run missing --image="$busybox" --restart=Never --overrides='{"spec":{"runtimeClassName":"does-not-exist"}}' -- sleep 60 2>&1 || true)"
expect 'API server rejects a missing RuntimeClass' "$missing" 'pods "missing" is forbidden: pod rejected: RuntimeClass "does-not-exist" not found'
# The page describes a class whose handler is gvisor, which containerd does not have.
kubectl apply -f - <<'MANIFEST'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: smoke-no-handler
handler: gvisor
MANIFEST
kubectl -n tenant-b run no-handler --image="$busybox" --restart=Never --overrides='{"spec":{"runtimeClassName":"smoke-no-handler"}}' -- sleep 60
sandbox_events="$(wait_for_event no-handler FailedCreatePodSandBox)"
expect 'kubelet reports FailedCreatePodSandBox' "$sandbox_events" FailedCreatePodSandBox
expect 'containerd names the missing handler' "$sandbox_events" 'no runtime for "gvisor" is configured'
expect 'Pod without a handler stays in ContainerCreating' "$(kubectl -n tenant-b get pod no-handler)" ContainerCreating
kubectl -n tenant-b delete pod no-handler --wait=false
kubectl delete runtimeclass smoke-no-handler

# gVisor and Kata compared
page=course-02-gvisor-and-kata-compared.md
expect 'RuntimeClass gvisor is unchanged' "$(save_from_page "$page" runtimeclass-gvisor.yaml)" unchanged
save_from_page "$page" pods-kernel-check.yaml
kubectl -n tenant-b wait --for=condition=Ready pod/kernel-check pod/kernel-check-gvisor --timeout=180s
node_kernel="$(uname -r)"
expect 'runc container reports the node kernel' "$(kubectl -n tenant-b exec kernel-check -- uname -r)" "$node_kernel"
expect 'gVisor container reports the gVisor kernel' "$(kubectl -n tenant-b exec kernel-check-gvisor -- uname -r)" 4.19.0-gvisor
gvisor_log="$(kubectl -n tenant-b exec kernel-check-gvisor -- dmesg)"
expect 'gVisor kernel log starts with Starting gVisor' "$gvisor_log" 'Starting gVisor...'
expect 'gVisor kernel log ends with Ready' "$gvisor_log" 'Ready!'
expect 'runc container may not read the node kernel log' "$(kubectl -n tenant-b exec kernel-check -- dmesg 2>&1 || true)" 'dmesg: klogctl: Operation not permitted'
expect 'containerd started kernel-check with the default handler' "$(sudo crictl pods --namespace tenant-b --name '^kernel-check$')" '(default)'
gvisor_processes="$(ps -eo rss,args | grep -E 'runsc-sandbox|runsc-gofer|containerd-shim-runsc' | grep -v grep | awk '{print $1, $2}')"
printf '%s\n' "$gvisor_processes"
expect 'node runs the runsc shim' "$gvisor_processes" containerd-shim-runsc-v1
expect 'node runs the Sentry process' "$gvisor_processes" runsc-sandbox
expect 'node runs the gofer process' "$gvisor_processes" runsc-gofer

# RuntimeClass scheduling and overhead
page=course-03-runtimeclass-scheduling-and-overhead.md
save_from_page "$page" runtimeclass-sandboxed.yaml
save_from_page "$page" pod-sandboxed-app.yaml
scheduling_events="$(wait_for_event sandboxed-app FailedScheduling)"
expect 'sandboxed-app stays Pending' "$(kubectl -n tenant-b get pod sandboxed-app)" Pending
expect 'scheduler reports FailedScheduling' "$scheduling_events" FailedScheduling
expect 'no node matches the selector of the class' "$scheduling_events" "0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector."
kubectl label node "$node_name" sandbox=true
kubectl -n tenant-b wait --for=condition=Ready pod/sandboxed-app --timeout=180s
merged_fields="$(kubectl -n tenant-b get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}')"
expect 'Pod carries the overhead of the class' "$merged_fields" '{"cpu":"50m","memory":"64Mi"}'
expect 'Pod carries the merged node selector' "$merged_fields" '{"sandbox":"true"}'
expect 'scheduler placed the Pod on the node' "$merged_fields" "$node_name"
node_request_line="$(kubectl describe node "$node_name" | grep sandboxed-app)"
expect 'node counts a CPU request of 50m' "$node_request_line" 50m
expect 'node counts a memory request of 64Mi' "$node_request_line" 64Mi
conflict="$(kubectl -n tenant-b run sb-conflict --image="$busybox" --restart=Never --dry-run=server --overrides='{"spec":{"runtimeClassName":"sandboxed","nodeSelector":{"sandbox":"false"}}}' -- sleep 3600 2>&1 || true)"
expect 'API server rejects a conflicting node selector' "$conflict" 'pods "sb-conflict" is forbidden: conflict: runtimeClass.scheduling.nodeSelector[sandbox] = true; pod.spec.nodeSelector[sandbox] = false'
wrong_overhead="$(kubectl -n tenant-b run sb-overhead --image="$busybox" --restart=Never --dry-run=server --overrides='{"spec":{"runtimeClassName":"sandboxed","overhead":{"cpu":"1m","memory":"1Mi"}}}' -- sleep 3600 2>&1 || true)"
expect 'API server rejects a different overhead' "$wrong_overhead" "pod rejected: Pod's Overhead doesn't match RuntimeClass's defined Overhead"

# Requiring the sandbox with admission policy
page=course-04-requiring-the-sandbox-with-admission-policy.md
expect 'RuntimeClass sandboxed is unchanged' "$(save_from_page "$page" runtimeclass-sandboxed.yaml)" unchanged
save_from_page "$page" policy-require-sandbox.yaml
save_from_page "$page" binding-require-sandbox.yaml
denied=''
for attempt in $(seq 1 15); do
  denied="$(kubectl -n tenant-b run plain --image="$busybox" --restart=Never --dry-run=server -- sleep 60 2>&1 || true)"
  [[ "$denied" == *denied* ]] && break
  sleep 2
done
printf '%s\n' "$denied"
expect 'policy rejects a Pod without a class' "$denied" "The pods \"plain\" is invalid: : ValidatingAdmissionPolicy 'require-sandbox' with binding 'require-sandbox-tenant-b' denied request: Pods must set runtimeClassName sandboxed"
save_yaml_from_page "$page" pod-policy-allowed.yaml
expect 'policy admits a Pod with the class' "$(kubectl apply -f "$work_directory/pod-policy-allowed.yaml" --dry-run=server)" 'pod/policy-allowed created (server dry run)'
expect 'binding does not select the default namespace' "$(kubectl -n default run plain --image="$busybox" --restart=Never --dry-run=server -- sleep 60)" 'pod/plain created (server dry run)'
classes="$(kubectl -n tenant-b get pods -o custom-columns=NAME:.metadata.name,CLASS:.spec.runtimeClassName)"
printf '%s\n' "$classes"
expect 'Pod created before the binding shows no class' "$(printf '%s\n' "$classes" | grep -E '^kernel-check ')" '<none>'
expect 'sandboxed Pod shows its class' "$(printf '%s\n' "$classes" | grep -E '^sandboxed-app ')" sandboxed
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
