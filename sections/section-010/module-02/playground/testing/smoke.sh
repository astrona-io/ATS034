#!/usr/bin/env bash
# Runs the commands that the module pages teach against this playground and
# fails when one of them does not give the result the page describes.
# It runs inside the playground VM as the student user. The VM is the only
# node, so node commands use sudo directly.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kubernetes-admin@astro-ats-034-playground-010-02" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
check_count=0

# Write the YAML block that follows "Save this as `<file>`" (or "as `<file>`") on a page.
write_from_page() {
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

save_from_page() {
  write_from_page "$1" "$2"
  kubectl apply -f "$work_directory/$2"
}

# Print the first YAML block on a page that contains the given text, indented
# by the given number of spaces. Some pages show a securityContext block only
# as a fragment; the script puts the fragment into a full Pod.
fragment_from_page() {
  python3 - "$module_directory/$1" "$2" "$3" <<'PY'
import re, sys
page, needle, indent = sys.argv[1], sys.argv[2], int(sys.argv[3])
for block in re.findall(r'```yaml\n(.*?)```', open(page).read(), re.S):
    if needle in block and 'kind:' not in block:
        print(''.join(' ' * indent + line for line in block.splitlines(True)), end='')
        break
else:
    sys.exit('no YAML fragment with ' + needle + ' in ' + page)
PY
}

expect() {
  check_count=$((check_count + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_absent() {
  check_count=$((check_count + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" != *"$3"* ]] || { printf 'FAIL: %s\nunwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Run a command until its output contains the text, at most 30 times, and
# print the last output.
wait_for_output() {
  local wanted="$1" output='' attempt
  shift
  for attempt in $(seq 1 30); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 2
  done
  printf '%s\n' "$output"
}

# Playground guide
expect 'hardened enforces Restricted' "$(kubectl get namespaces starfleet outpost hardened -L pod-security.kubernetes.io/enforce)" restricted
expect 'scanner Deployment has no Pod' "$(kubectl -n hardened get deployment scanner)" '0/1'
events="$(wait_for_output 'is forbidden' kubectl -n hardened get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message --no-headers)"
printf '%s\n' "$events" | head -1
expect 'FailedCreate names Restricted' "$events" 'violates PodSecurity "restricted:v1.35"'
expect 'FailedCreate names allowPrivilegeEscalation' "$events" 'must set securityContext.allowPrivilegeEscalation=false'
expect 'FailedCreate names capabilities' "$events" 'must set securityContext.capabilities.drop=["ALL"]'
expect 'FailedCreate names runAsNonRoot' "$events" 'must set securityContext.runAsNonRoot=true'
expect 'FailedCreate names seccompProfile' "$events" 'must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost"'
expect 'shuttle runs as root' "$(kubectl -n starfleet exec shuttle -- id)" 'uid=0(root) gid=0(root)'
shuttle_status="$(kubectl -n starfleet exec shuttle -- grep -E 'CapEff|NoNewPrivs|Seccomp:' /proc/1/status)"
printf '%s\n' "$shuttle_status"
expect 'shuttle has the default capabilities' "$shuttle_status" $'CapEff:\t00000000a80425fb'
expect 'shuttle may gain privileges' "$shuttle_status" $'NoNewPrivs:\t0'
expect 'shuttle has no seccomp filter' "$shuttle_status" $'Seccomp:\t0'
profiles="$(ls /opt/profiles)"
expect 'setup placed the seccomp file' "$profiles" block-mkdir.json
expect 'setup placed the AppArmor file' "$profiles" k8s-deny-tmp-write

# Run as a non-root user
page=course-01-run-as-a-non-root-user.md
kubectl create namespace users-demo
save_from_page "$page" pod-default-user.yaml
kubectl -n users-demo wait --for=condition=Ready pod/default-user --timeout=120s
expect 'image without USER runs as root' "$(kubectl -n users-demo exec default-user -- id)" 'uid=0(root)'
save_from_page "$page" pod-chosen-user.yaml
kubectl -n users-demo wait --for=condition=Ready pod/chosen-user --timeout=120s
chosen_id="$(kubectl -n users-demo exec chosen-user -- id)"
printf '%s\n' "$chosen_id"
expect 'runAsUser and runAsGroup set the IDs' "$chosen_id" 'uid=10001 gid=10001'
expect 'fsGroup is a supplementary group' "$chosen_id" 20001
data_listing="$(kubectl -n users-demo exec chosen-user -- ls -ld /data)"
printf '%s\n' "$data_listing"
expect 'volume belongs to the fsGroup' "$(printf '%s' "$data_listing" | awk '{print $4}')" 20001
expect 'group may write the volume' "${data_listing:5:1}" w
save_from_page "$page" pod-nonroot-check.yaml
expect 'kubelet refuses the root image' "$(wait_for_output CreateContainerConfigError kubectl -n users-demo get pod nonroot-check)" CreateContainerConfigError
expect 'event names runAsNonRoot and the root image' "$(wait_for_output 'image will run as root' kubectl -n users-demo describe pod nonroot-check)" 'has runAsNonRoot and image will run as root'

# Capabilities and privilege escalation
page=course-02-capabilities-and-privilege-escalation.md
kubectl create namespace caps-demo
write_from_page "$page" pod-caps-default.yaml
write_from_page "$page" pod-caps-dropped.yaml
kubectl apply -f "$work_directory/pod-caps-default.yaml" -f "$work_directory/pod-caps-dropped.yaml"
kubectl -n caps-demo wait --for=condition=Ready pod/caps-default pod/caps-dropped --timeout=120s
default_caps="$(kubectl -n caps-demo exec caps-default -- grep Cap /proc/1/status)"
dropped_caps="$(kubectl -n caps-demo exec caps-dropped -- grep Cap /proc/1/status)"
printf '%s\n%s\n' "$default_caps" "$dropped_caps"
expect_absent 'default CapEff is not zero' "$(printf '%s\n' "$default_caps" | grep CapEff)" 0000000000000000
expect_absent 'default CapBnd is not zero' "$(printf '%s\n' "$default_caps" | grep CapBnd)" 0000000000000000
expect 'dropped container shows five capability lines' "$(printf '%s\n' "$dropped_caps" | grep -c Cap)" 5
expect 'every dropped line is zero' "$(printf '%s\n' "$dropped_caps" | grep -vc $'\t0000000000000000$' || true)" 0
expect 'chown works with CHOWN' "$(kubectl -n caps-demo exec caps-default -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok' 2>&1)" chown-ok
expect 'chown fails without CHOWN' "$(kubectl -n caps-demo exec caps-dropped -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok' 2>&1 || true)" 'Operation not permitted'
expect 'NoNewPrivs is 0 by default' "$(kubectl -n caps-demo exec caps-default -- grep NoNewPrivs /proc/1/status)" $'NoNewPrivs:\t0'
# The page says its NET_BIND_SERVICE block is valid under Restricted. Put it
# into a non-root Pod with a seccomp profile and send that Pod to the
# Restricted namespace hardened as a server-side dry run.
cat > "$work_directory/pod-bind-service.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: bind-service
  namespace: hardened
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
$(fragment_from_page "$page" NET_BIND_SERVICE 4)
YAML
expect 'NET_BIND_SERVICE block passes Restricted' "$(kubectl apply -f "$work_directory/pod-bind-service.yaml" --dry-run=server 2>&1)" 'created (server dry run)'

# Seccomp, AppArmor and SELinux
page=course-03-seccomp-and-mandatory-access-control.md
kubectl create namespace seccomp-demo
write_from_page "$page" pod-seccomp-runtime.yaml
write_from_page "$page" pod-seccomp-unconfined.yaml
kubectl apply -f "$work_directory/pod-seccomp-runtime.yaml" -f "$work_directory/pod-seccomp-unconfined.yaml"
kubectl -n seccomp-demo wait --for=condition=Ready pod/seccomp-runtime pod/seccomp-unconfined --timeout=120s
expect 'RuntimeDefault filter is active' "$(kubectl -n seccomp-demo exec seccomp-runtime -- grep Seccomp: /proc/1/status)" $'Seccomp:\t2'
expect 'Unconfined has no filter' "$(kubectl -n seccomp-demo exec seccomp-unconfined -- grep Seccomp: /proc/1/status)" $'Seccomp:\t0'
label_output="$(kubectl label namespace seccomp-demo pod-security.kubernetes.io/enforce=baseline --overwrite 2>&1)"
printf '%s\n' "$label_output"
expect 'label warning names the running Pod' "$label_output" seccomp-unconfined
expect 'label is still applied' "$label_output" 'namespace/seccomp-demo labeled'
kubectl delete pod seccomp-unconfined -n seccomp-demo
denied="$(kubectl apply -f "$work_directory/pod-seccomp-unconfined.yaml" --dry-run=server 2>&1 || true)"
printf '%s\n' "$denied"
expect 'Baseline forbids Unconfined' "$denied" Forbidden
expect 'error names baseline:latest' "$denied" 'baseline:latest'
expect 'error names seccompProfile' "$denied" seccompProfile
expect 'error names the value Unconfined' "$denied" Unconfined
sudo install -D -m 0644 /opt/profiles/block-mkdir.json /var/lib/kubelet/seccomp/profiles/block-mkdir.json
seccomp_listing="$(sudo ls -l /var/lib/kubelet/seccomp/profiles)"
printf '%s\n' "$seccomp_listing"
expect 'seccomp file is on the node' "$seccomp_listing" '-rw-r--r-- 1 root root 143 '
expect 'seccomp file has its name' "$seccomp_listing" block-mkdir.json
sudo apparmor_parser -r /opt/profiles/k8s-deny-tmp-write
expect 'AppArmor profile is loaded' "$(sudo grep k8s-deny /sys/kernel/security/apparmor/profiles)" 'k8s-deny-tmp-write (enforce)'
# The page shows the profile fields as a container securityContext fragment
# and creates the Pod again with them.
kubectl delete pod seccomp-runtime -n seccomp-demo
cat > "$work_directory/pod-seccomp-runtime-localhost.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime
  namespace: seccomp-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
$(fragment_from_page "$page" k8s-deny-tmp-write 4)
YAML
kubectl apply -f "$work_directory/pod-seccomp-runtime-localhost.yaml"
kubectl -n seccomp-demo wait --for=condition=Ready pod/seccomp-runtime --timeout=120s
expect 'Localhost seccomp filter is active' "$(kubectl -n seccomp-demo exec seccomp-runtime -- grep Seccomp: /proc/1/status)" $'Seccomp:\t2'
expect 'AppArmor profile is attached' "$(kubectl -n seccomp-demo exec seccomp-runtime -- cat /proc/1/attr/current)" 'k8s-deny-tmp-write (enforce)'
mkdir_output="$(kubectl -n seccomp-demo exec seccomp-runtime -- mkdir /data 2>&1 || true)"
printf '%s\n' "$mkdir_output"
expect 'seccomp blocks mkdir' "$mkdir_output" "mkdir: can't create directory '/data': Operation not permitted"
expect 'failed command reports exit code 1' "$mkdir_output" 'command terminated with exit code 1'
write_output="$(kubectl -n seccomp-demo exec seccomp-runtime -- sh -c 'echo test > /tmp/test' 2>&1 || true)"
printf '%s\n' "$write_output"
expect 'AppArmor blocks the write below /tmp' "$write_output" "sh: can't create /tmp/test: Permission denied"
# The page names the event of a wrong localhostProfile path.
cat > "$work_directory/pod-seccomp-wrong-path.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-wrong-path
  namespace: seccomp-demo
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: block-mkdir.json
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
YAML
kubectl apply -f "$work_directory/pod-seccomp-wrong-path.yaml"
wrong_path="$(wait_for_output 'no such file or directory' kubectl -n seccomp-demo describe pod seccomp-wrong-path)"
expect 'wrong path leaves CreateContainerError' "$(kubectl -n seccomp-demo get pod seccomp-wrong-path)" CreateContainerError
expect 'event names the missing file' "$wrong_path" 'cannot load seccomp profile "/var/lib/kubelet/seccomp/block-mkdir.json": open /var/lib/kubelet/seccomp/block-mkdir.json: no such file or directory'

# Host namespaces and host paths
page=course-04-host-namespaces-and-host-paths.md
save_from_page "$page" namespace-host-demo.yaml
write_from_page "$page" pod-host-namespaces.yaml
host_namespaces="$(kubectl apply -f "$work_directory/pod-host-namespaces.yaml" --dry-run=server 2>&1 || true)"
printf '%s\n' "$host_namespaces"
expect 'Baseline forbids host namespaces' "$host_namespaces" Forbidden
expect 'error names baseline:latest' "$host_namespaces" 'baseline:latest'
expect 'one message covers hostNetwork and hostPID' "$host_namespaces" 'host namespaces (hostNetwork=true, hostPID=true)'
write_from_page "$page" pod-host-path.yaml
host_path="$(kubectl apply -f "$work_directory/pod-host-path.yaml" --dry-run=server 2>&1 || true)"
printf '%s\n' "$host_path"
expect 'Baseline forbids hostPath' "$host_path" Forbidden
expect 'error names hostPath volumes and node-logs' "$host_path" 'hostPath volumes (volume "node-logs")'
write_from_page "$page" pod-scratch.yaml
expect 'emptyDir Pod is admitted' "$(kubectl apply -f "$work_directory/pod-scratch.yaml" --dry-run=server)" 'created (server dry run)'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$check_count"
