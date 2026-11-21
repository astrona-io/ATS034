#!/usr/bin/env bash
# Runs the commands that the module pages teach inside the playground VM and
# fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user.
set -euo pipefail
cluster_name=astro-ats-034-playground-020-01
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster_name}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
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

# Print the text block that follows a sentence on a page (the output the page shows).
text_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, sentence = sys.argv[1:]
text = open(page).read()
match = re.search(re.escape(sentence) + r'.*?```text\n(.*?)```', text, re.S)
if not match:
    sys.exit('no text block after "' + sentence + '" in ' + page)
sys.stdout.write(match.group(1))
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_absent() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" != *"$3"* ]] || { printf 'FAIL: %s\nunwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Wait until a Pod shows a status, at most about 90 seconds.
wait_for_pod_status() {
  local namespace="$1" pod="$2" status="$3" output=''
  for attempt in $(seq 1 45); do
    output="$(kubectl -n "$namespace" get pod "$pod" 2>&1 || true)"
    [[ "$output" == *"$status"* ]] && break
    sleep 2
  done
  printf '%s\n' "$output"
}

# Run a check command in a Pod until it prints the wanted word, at most about 3 minutes.
wait_for_output() {
  local wanted="$1" output=''
  shift
  for attempt in $(seq 1 36); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 5
  done
  printf '%s\n' "$output"
}

# The helper of the encryption at rest page: read one key from etcd.
etcd_get() {
  sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    get "$1"
}

# The first bytes of the stored value of a key (the line after the key).
stored_prefix() {
  etcd_get "$1" | tail -n +2 | head -c "$2"
}

# Count the stored values that contain the text, as `grep -a -c` on the page.
count_in_etcd() {
  etcd_get "$1" | grep -a -c "$2" || true
}

# Playground guide: the starting state
expect 'kubectl uses the playground context' "$(kubectl config current-context)" "kubernetes-admin@$cluster_name"
start_state="$(kubectl -n starfleet get pods,secrets)"
printf '%s\n' "$start_state"
expect 'shuttle runs in starfleet' "$start_state" 'Running'
expect 'Secret practice-token exists' "$start_state" 'secret/practice-token'
expect 'drifter runs in outpost' "$(kubectl -n outpost get pod drifter)" Running
expect 'practice-token holds disposable-v1' "$(test "$(kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}' | base64 -d)" = disposable-v1 && echo match || echo different)" match

# Playground guide: rotate the value and refresh the consumer
guide=playground/docs/overview.md
save_from_page "$guide" pod-rotated-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/rotated-reader --timeout=180s
expect 'guide: Secret update prints configured' "$(save_from_page "$guide" secret-practice-token.yaml)" 'secret/practice-token configured'
guide_file_after_sync="$(wait_for_output file-new kubectl -n starfleet exec rotated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo file-new || echo file-old')"
expect 'guide: kubelet refreshes the file to file-new' "$guide_file_after_sync" file-new
expect 'guide: environment variable stays env-old' "$(kubectl -n starfleet exec rotated-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo env-new || echo env-old')" env-old
kubectl -n starfleet delete pod rotated-reader --wait=true
kubectl apply -f "$work_directory/pod-rotated-reader.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/rotated-reader --timeout=180s
expect 'guide: new Pod has env-new' "$(kubectl -n starfleet exec rotated-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo env-new || echo env-old')" env-new
# The pages start from the playground state again: practice-token holds
# disposable-v1, as the bootstrap applied it, and rotated-reader is gone. The
# rotation page then applies the same secret-practice-token.yaml and expects
# "configured" and an old environment variable, which only holds after this
# reset.
kubectl -n starfleet delete pod rotated-reader --wait=true
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: practice-token
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v1
YAML
expect 'practice-token holds disposable-v1 again' "$(test "$(kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}' | base64 -d)" = disposable-v1 && echo match || echo different)" match

# What a Secret is and who can read it
page=course-01-what-a-secret-is-and-who-can-read-it.md
stored_token="$(kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}')"
expect 'stored value ends with =' "${stored_token: -1}" '='
expect 'base64 decodes to disposable-v1' "$(kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}' | base64 --decode)" disposable-v1
expect 'kubectl creates api-key' "$(save_from_page "$page" secret-api-key.yaml)" 'secret/api-key created'
api_key_yaml="$(kubectl -n starfleet get secret api-key -o yaml)"
expect 'API server stored the value in data' "$api_key_yaml" "key: $(printf disposable-api-key | base64)"
# Only the field: kubectl apply keeps the applied manifest, stringData included, in an annotation.
expect_absent 'API server stores no stringData field' "$api_key_yaml" $'\nstringData:'
expect 'describe shows the size, not the value' "$(kubectl -n starfleet describe secret api-key)" 'key:  18 bytes'
expect_absent 'describe hides the value' "$(kubectl -n starfleet describe secret api-key)" disposable-api-key
expect 'default ServiceAccount may not get Secrets' "$(kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:default || true)" no
expect 'default ServiceAccount may not list Secrets' "$(kubectl auth can-i list secrets -n starfleet --as=system:serviceaccount:starfleet:default || true)" no
expect 'the student user may get Secrets' "$(kubectl auth can-i get secrets -n starfleet)" yes

# Delivering Secrets to Pods
page=course-02-delivering-secrets-to-pods.md
save_from_page "$page" pod-delivery-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/delivery-reader --timeout=120s
expect 'environment variable holds the value' "$(kubectl -n starfleet exec delivery-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v1 && echo match || echo different')" match
expect 'file holds the value' "$(kubectl -n starfleet exec delivery-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1 && echo match || echo different')" match
volume_listing="$(kubectl -n starfleet exec delivery-reader -- ls -la /credentials)"
printf '%s\n' "$volume_listing"
expect 'token is a link into ..data' "$volume_listing" 'token -> ..data/token'
expect '..data points at a timestamped directory' "$volume_listing" '..data -> ..'
expect 'defaultMode 0400 gives -r--------' "$(kubectl -n starfleet exec delivery-reader -- ls -lL /credentials/token)" '-r--------'
# The page says what a missing Secret does to each path; the Pods name a Secret that does not exist.
kubectl -n starfleet run missing-env --image="$busybox" --restart=Never --overrides='{"spec":{"containers":[{"name":"missing-env","image":"'"$busybox"'","command":["sleep","3600"],"env":[{"name":"TOKEN","valueFrom":{"secretKeyRef":{"name":"does-not-exist","key":"token"}}}]}]}}'
kubectl -n starfleet run missing-volume --image="$busybox" --restart=Never --overrides='{"spec":{"containers":[{"name":"missing-volume","image":"'"$busybox"'","command":["sleep","3600"],"volumeMounts":[{"name":"credentials","mountPath":"/credentials"}]}],"volumes":[{"name":"credentials","secret":{"secretName":"does-not-exist"}}]}}'
expect 'missing Secret in env gives CreateContainerConfigError' "$(wait_for_pod_status starfleet missing-env CreateContainerConfigError)" CreateContainerConfigError
sleep 10
expect 'missing Secret volume leaves ContainerCreating' "$(kubectl -n starfleet get pod missing-volume)" ContainerCreating
kubectl -n starfleet delete pod missing-env missing-volume --wait=false

# Rotating a Secret
page=course-03-rotating-a-secret.md
save_from_page "$page" pod-rotation-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/rotation-reader --timeout=120s
expect 'Secret update prints configured' "$(save_from_page "$page" secret-practice-token.yaml)" 'secret/practice-token configured'
expect 'environment variable keeps the old value' "$(kubectl -n starfleet exec rotation-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old')" old
file_after_sync="$(wait_for_output new kubectl -n starfleet exec rotation-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo new || echo old')"
expect 'kubelet refreshes the file to the new value' "$file_after_sync" new
expect 'environment variable still holds the old value' "$(kubectl -n starfleet exec rotation-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old')" old
kubectl -n starfleet delete pod rotation-reader --wait=true
kubectl apply -f "$work_directory/pod-rotation-reader.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/rotation-reader --timeout=120s
expect 'new Pod reads the new value' "$(kubectl -n starfleet exec rotation-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old')" new
# The page says an immutable Secret rejects every change to data.
kubectl -n starfleet create secret generic smoke-immutable --from-literal=token=disposable-fixed --dry-run=client -o json \
  | python3 -c 'import json, sys; secret = json.load(sys.stdin); secret["immutable"] = True; print(json.dumps(secret))' \
  | kubectl apply -f -
immutable_change="$(kubectl -n starfleet patch secret smoke-immutable -p '{"stringData":{"token":"disposable-changed"}}' 2>&1 || true)"
expect 'immutable Secret rejects a change to data' "$immutable_change" 'field is immutable when `immutable` is set'
kubectl -n starfleet delete secret smoke-immutable

# Encryption at rest
page=course-04-encryption-at-rest.md
expect 'kubectl creates before-encryption' "$(kubectl -n starfleet create secret generic before-encryption --from-literal=token=disposable-before)" 'secret/before-encryption created'
expect 'etcd key starts with the Secret path' "$(etcd_get /registry/secrets/starfleet/before-encryption | hexdump -C | head -5)" '|/registry/secret|'
expect 'stored value is plain protobuf (k8s and a zero byte)' "$(stored_prefix /registry/secrets/starfleet/before-encryption 4 | hexdump -C)" '6b 38 73 00'
expect 'value is readable text in etcd' "$(etcd_get /registry/secrets/starfleet/before-encryption | grep -a -o 'disposable-[a-z]*')" disposable-before
key="$(head -c 32 /dev/urandom | base64)"
expect 'key is 32 bytes' "$(printf '%s' "$key" | base64 -d | wc -c | tr -d ' ')" 32
save_yaml_from_page "$page" encryptionconfiguration.yaml
sed -i "s|<KEY>|$key|" "$work_directory/encryptionconfiguration.yaml"
sudo mkdir -p /etc/kubernetes/enc
sudo cp "$work_directory/encryptionconfiguration.yaml" /etc/kubernetes/enc/enc.yaml
sudo chmod 600 /etc/kubernetes/enc/enc.yaml
rm "$work_directory/encryptionconfiguration.yaml"
expect 'enc.yaml is owned by root with mode 600' "$(sudo ls -l /etc/kubernetes/enc)" '-rw------- 1 root root'
sudo mkdir -p /root/backup
sudo cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
# The page edits the manifest with vi; sed makes the same three additions.
sudo sed -i \
  -e 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|' \
  -e 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|' \
  -e 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
manifest_diff="$(sudo diff /root/backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml || true)"
printf '%s\n' "$manifest_diff"
expect 'diff prints exactly the three additions on the page' "$manifest_diff"$'\n' "$(text_from_page "$page" 'printed exactly the three additions:')"
# Wait until the old kube-apiserver process is gone and only the new one with
# the flag runs, then until it is ready (about 5 minutes at most).
apiserver_processes=''
for attempt in $(seq 1 60); do
  apiserver_processes="$(pgrep -af '^kube-apiserver ' || true)"
  [[ "$(printf '%s\n' "$apiserver_processes" | grep -c .)" == 1 && "$apiserver_processes" == *--encryption-provider-config=* ]] && break
  sleep 5
done
ready=''
for attempt in $(seq 1 60); do
  ready="$(kubectl get --raw=/readyz 2>/dev/null || true)"
  [[ "$ready" == ok ]] && break
  sleep 5
done
expect 'API server answers readyz after the restart' "$ready" ok
apiserver_container="$(sudo crictl ps --name kube-apiserver)"
printf '%s\n' "$apiserver_container"
expect 'one kube-apiserver container is Running' "$apiserver_container" Running
expect 'kube-apiserver runs with the encryption flag' "$(pgrep -af kube-apiserver)" '--encryption-provider-config=/etc/kubernetes/enc/enc.yaml'
expect 'kubectl creates after-encryption' "$(kubectl -n starfleet create secret generic after-encryption --from-literal=token=disposable-after)" 'secret/after-encryption created'
expect 'new Secret has the aescbc prefix' "$(etcd_get /registry/secrets/starfleet/after-encryption | hexdump -C | head -5)" '|r-encryption.k8s|'
expect 'new Secret starts with k8s:enc:aescbc:v1:key1:' "$(stored_prefix /registry/secrets/starfleet/after-encryption 23)" 'k8s:enc:aescbc:v1:key1:'
expect 'new Secret is not readable in etcd' "$(count_in_etcd /registry/secrets/starfleet/after-encryption disposable)" 0
expect 'old Secret is still plain in etcd' "$(count_in_etcd /registry/secrets/starfleet/before-encryption disposable)" 1
replaced="$(kubectl get secrets --all-namespaces -o json | kubectl replace -f -)"
printf '%s\n' "$replaced"
expect 'replace writes the bootstrap token again' "$replaced" 'secret/bootstrap-token-'
expect 'replace writes after-encryption again' "$replaced" 'secret/after-encryption replaced'
expect 'replace writes before-encryption again' "$replaced" 'secret/before-encryption replaced'
expect 'replace writes practice-token again' "$replaced" 'secret/practice-token replaced'
expect 'old Secret now starts with k8s:enc:aescbc:v1:key1:' "$(stored_prefix /registry/secrets/starfleet/before-encryption 23)" 'k8s:enc:aescbc:v1:key1:'
expect 'old Secret is no longer readable in etcd' "$(count_in_etcd /registry/secrets/starfleet/before-encryption disposable)" 0
expect 'API server still decrypts the old Secret' "$(kubectl -n starfleet get secret before-encryption -o jsonpath='{.data.token}' | base64 -d; echo)" disposable-before
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
