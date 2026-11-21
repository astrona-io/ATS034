#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-020-01-04}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-034-020-01-04"
source "$lab_directory/bootstrap/helpers.sh"
config=/etc/kubernetes/enc/enc.yaml

# The kube-apiserver reads the EncryptionConfiguration only when it starts.
# The static pod manifest does not change, so stop the container: the
# kubelet starts a new container in the same pod.
restart_apiserver() {
  local old_container new_container attempt
  old_container="$(run_on_node crictl ps --name kube-apiserver -q)"
  run_on_node crictl stop "$old_container" >/dev/null
  for attempt in $(seq 1 60); do
    new_container="$(run_on_node crictl ps --name kube-apiserver -q)"
    if [[ -n "$new_container" && "$new_container" != "$old_container" ]]; then
      wait_for_api
      return 0
    fi
    sleep 3
  done
  printf 'Timed out waiting for a new kube-apiserver container\n' >&2
  return 1
}

write_config() {
  run_on_node tee "$config" >/dev/null
  run_on_node chmod 600 "$config"
}

old_key="$(run_on_node sed -n 's/^ *secret: *//p' "$config" | head -1)"
new_key="$(head -c 32 /dev/urandom | base64)"

# 1. key2 goes first, so new writes use it. key1 stays, so the API server
#    can still read the Secrets that etcd stores with key1.
write_config <<CONFIG
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key2
        secret: $new_key
      - name: key1
        secret: $old_key
  - identity: {}
CONFIG
restart_apiserver

# 2. Write every Secret again, so etcd stores all of them with key2.
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# 3. Remove key1 and restart, so the API server no longer holds it.
write_config <<CONFIG
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key2
        secret: $new_key
  - identity: {}
CONFIG
restart_apiserver
