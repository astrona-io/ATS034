#!/usr/bin/env bash
# Runs the commands that the module pages teach inside the playground VM and
# fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node, so
# node commands use sudo directly.
set -euo pipefail
cluster_name=astro-ats-034-playground-020-03
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster_name}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
apiserver_manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
audit_log=/var/log/kubernetes/audit/audit.log
auditor=system:serviceaccount:starfleet:auditor

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

# Print the text block that follows the first code block containing the given
# command on a page: the output the page shows for that command.
output_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
text = open(page).read()
match = re.search(r'```sh\n[^`]*' + re.escape(command) + r'[^`]*```\s*```(?:text|json)\n(.*?)```', text, re.S)
if not match:
    sys.exit('no output block after ' + command + ' in ' + page)
print(match.group(1), end='')
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Print the audit flags of the running kube-apiserver, as the page does.
audit_flags() {
  ps -ef | grep -o -- '--audit-[a-z-]*=[^ ]*' || true
}

# Wait until the new kube-apiserver runs with the audit flags and answers
# /readyz, at most about 5 minutes.
wait_for_audited_apiserver() {
  local attempt
  for attempt in $(seq 1 60); do
    if [[ "$(audit_flags)" == *--audit-log-path* ]] && [[ "$(kubectl get --raw=/readyz 2>/dev/null)" == ok ]]; then
      return 0
    fi
    sleep 5
  done
  printf 'kube-apiserver did not come back with the audit flags\n' >&2
  sudo crictl ps -a --name kube-apiserver >&2 || true
  exit 1
}

# Print the Secret events of auditor as one line each, with the filter of the
# page, waiting until there are at least the given number, at most 60 seconds.
auditor_events() {
  local wanted="$1" lines='' attempt
  for attempt in $(seq 1 30); do
    lines="$(sudo grep '"resource":"secrets"' "$audit_log" | jq -c 'select(.impersonatedUser.username // .user.username | test("auditor")) | {user: (.impersonatedUser.username // .user.username), verb, name: .objectRef.name, code: .responseStatus.code, level}' || true)"
    [[ "$(printf '%s' "$lines" | grep -c . || true)" -ge "$wanted" ]] && break
    sleep 2
  done
  printf '%s\n' "$lines"
}

# Where credentials leak
page=course-01-where-credentials-leak.md
expect_equal 'ConfigMap legacy-settings holds a credential key' "$(kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential)" 1
save_from_page "$page" pod-leaky.yaml
expect 'describe shows the literal value' "$(kubectl -n starfleet describe pod leaky | grep PRACTICE_TOKEN)" 'PRACTICE_TOKEN:  disposable-v1'
save_from_page "$page" secret-practice-applied.yaml
expect_equal 'last-applied annotation holds the plain value' "$(kubectl -n starfleet get secret practice-applied -o jsonpath='{.metadata.annotations}' | grep -c disposable)" 1
save_from_page "$page" secret-practice-moved.yaml
kubectl -n starfleet wait --for=condition=Ready pod/moved-reader --timeout=120s
expect_equal 'mounted Secret file holds the value' "$(kubectl -n starfleet exec moved-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1 && echo match')" match

# Playground guide
expect_equal 'guide: ConfigMap holds a credential key' "$(kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential)" 1
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect 'shuttle is Running' "$(printf '%s\n' "$pods" | grep -E '^shuttle ')" Running
guide=playground/docs/overview.md
save_from_page "$guide" secret-migrated-credentials.yaml
kubectl -n starfleet wait --for=condition=Ready pod/migrated-reader --timeout=180s
expect 'migrated Secret file holds the value' "$(kubectl -n starfleet exec migrated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1' && echo passed)" passed
expect 'deleting the ConfigMap succeeds' "$(kubectl -n starfleet delete configmap legacy-settings)" 'configmap "legacy-settings" deleted'
expect 'no environment variable holds the credential' "$(kubectl -n starfleet exec migrated-reader -- sh -c 'test -z "$(env | grep disposable)"' && echo passed)" passed
expect 'ConfigMap is gone' "$(kubectl -n starfleet get configmap legacy-settings 2>&1 || true)" 'Error from server (NotFound): configmaps "legacy-settings" not found'
# The first page says that after the guide deleted legacy-settings, its first
# command shows a NotFound error and prints 0. Run that exact command again.
deleted_count="$(kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' 2>"$work_directory/deleted-stderr" | grep -c credential || true)"
expect_equal 'first page command prints 0 after the guide deleted the ConfigMap' "$deleted_count" 0
expect 'first page command shows a NotFound error after the guide deleted the ConfigMap' "$(cat "$work_directory/deleted-stderr")" NotFound

# Auditing Secret access
page=course-04-auditing-secret-access.md
expect_equal 'API server starts without audit flags' "$(audit_flags)" ''
save_yaml_from_page "$page" policy-audit.yaml
cd "$work_directory"
sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
sudo cp policy-audit.yaml /etc/kubernetes/audit/policy.yaml
sudo chmod 600 /etc/kubernetes/audit/policy.yaml
policy_listing="$(sudo ls -l /etc/kubernetes/audit)"
printf '%s\n' "$policy_listing"
expect 'policy file is root only, 187 bytes' "$policy_listing" '-rw------- 1 root root 187 '
expect 'policy file has its name' "$policy_listing" policy.yaml
sudo mkdir -p /root/backup
sudo cp -p "$apiserver_manifest" /root/backup/kube-apiserver.yaml
# The page edits the manifest with vi. Make the same edit: the four flags right
# after kube-apiserver, the two mounts at the top of volumeMounts and the two
# hostPath volumes at the top of volumes, then compare with the diff that the
# page shows.
sudo python3 - "$apiserver_manifest" <<'PY'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines(True)
flags = [
    '    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n',
    '    - --audit-log-path=/var/log/kubernetes/audit/audit.log\n',
    '    - --audit-log-maxage=7\n',
    '    - --audit-log-maxbackup=2\n',
]
mounts = [
    '    - mountPath: /etc/kubernetes/audit/policy.yaml\n',
    '      name: audit-policy\n',
    '      readOnly: true\n',
    '    - mountPath: /var/log/kubernetes/audit\n',
    '      name: audit-log\n',
]
volumes = [
    '  - hostPath:\n',
    '      path: /etc/kubernetes/audit/policy.yaml\n',
    '      type: File\n',
    '    name: audit-policy\n',
    '  - hostPath:\n',
    '      path: /var/log/kubernetes/audit\n',
    '      type: DirectoryOrCreate\n',
    '    name: audit-log\n',
]
def insert_after(header, block):
    index = lines.index(header) + 1
    lines[index:index] = block
insert_after('  volumes:\n', volumes)
insert_after('    volumeMounts:\n', mounts)
insert_after('    - kube-apiserver\n', flags)
open(path, 'w').write(''.join(lines))
PY
manifest_diff="$(sudo diff /root/backup/kube-apiserver.yaml "$apiserver_manifest" || true)"
printf '%s\n' "$manifest_diff"
expect_equal 'manifest diff matches the page' "$manifest_diff" "$(output_from_page "$page" 'sudo diff /root/backup')"
wait_for_audited_apiserver
expect_equal 'API server is ready' "$(kubectl get --raw=/readyz)" ok
flags="$(audit_flags)"
printf '%s\n' "$flags"
expect_equal 'API server runs with the four audit flags' "$flags" "$(output_from_page "$page" 'until kubectl get --raw=/readyz' | sed -n '2,5p')"
log_listing="$(sudo ls -l /var/log/kubernetes/audit)"
printf '%s\n' "$log_listing"
expect 'audit log is root only' "$log_listing" '-rw------- 1 root root '
expect 'audit log has its name' "$log_listing" audit.log
save_from_page "$page" role-auditor.yaml
allowed="$(kubectl -n starfleet get secret practice-token --as="$auditor")"
printf '%s\n' "$allowed"
expect 'auditor may get practice-token' "$allowed" 'practice-token   Opaque   1'
denied="$(kubectl -n starfleet get secrets --as="$auditor" 2>&1 || true)"
expect_equal 'auditor may not list Secrets' "$denied" 'Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:starfleet:auditor" cannot list resource "secrets" in API group "" in the namespace "starfleet"'
events="$(auditor_events 2)"
printf '%s\n' "$events"
expect_equal 'one line per auditor Secret event, as on the page' "$events" "$(output_from_page "$page" '"resource":"secrets"')"
get_event="$(sudo grep '"name":"practice-token"' "$audit_log" | grep '"verb":"get"' | grep auditor | tail -1 | jq .)"
expect 'get event has level Metadata' "$get_event" '"level": "Metadata"'
expect 'get event has stage ResponseComplete' "$get_event" '"stage": "ResponseComplete"'
expect 'get event names the request URI' "$get_event" '"requestURI": "/api/v1/namespaces/starfleet/secrets/practice-token"'
expect 'get event names the admin as user' "$get_event" '"username": "kubernetes-admin"'
expect 'get event names the impersonated auditor' "$get_event" "\"username\": \"$auditor\""
expect 'get event has code 200' "$get_event" '"code": 200'
expect 'get event names the RoleBinding' "$get_event" '"authorization.k8s.io/reason": "RBAC: allowed by RoleBinding \"auditor-practice-token-reader/starfleet\" of Role \"practice-token-reader\" to ServiceAccount \"auditor/starfleet\""'
expect_equal 'get event has no request or response body' "$(printf '%s' "$get_event" | jq -r '[has("requestObject"), has("responseObject")] | map(tostring) | join(" ")')" 'false false'
expect_equal 'no Secret value reached the audit log' "$(sudo grep -c disposable "$audit_log" || true)" 0
review="$(kubectl -n starfleet auth can-i --list --as="$auditor")"
secrets_line="$(printf '%s\n' "$review" | grep -E '^secrets ')"
printf '%s\n' "$secrets_line"
expect 'review shows get on practice-token' "$secrets_line" '[practice-token]   [get]'
expect_equal 'review shows one Secret line' "$(printf '%s\n' "$review" | grep -cE '^secrets ')" 1
bindings="$(kubectl -n starfleet get rolebindings -o wide)"
printf '%s\n' "$bindings"
expect 'binding uses Role practice-token-reader' "$bindings" 'auditor-practice-token-reader   Role/practice-token-reader'
expect 'binding names starfleet/auditor' "$bindings" starfleet/auditor

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
