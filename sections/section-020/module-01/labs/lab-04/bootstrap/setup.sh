#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Starting state: encryption at rest is on with one aescbc key, key1, and
# every Secret in etcd is stored with key1.
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

kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"

# key1: a random 32-byte aescbc key, written only to root-owned files.
key="$(head -c 32 /dev/urandom | base64)"
run_on_node mkdir -p /etc/kubernetes/enc /root/backup /var/lib/astrona-lab
run_on_node install -m 600 /dev/null /etc/kubernetes/enc/enc.yaml
run_on_node tee /etc/kubernetes/enc/enc.yaml >/dev/null <<CONFIG
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: $key
  - identity: {}
CONFIG
# The graders recognize the value of key1 by this hash, under any key name.
run_on_node install -m 600 /dev/null /var/lib/astrona-lab/key1.sha256
printf '%s' "$key" | sha256sum | cut -d' ' -f1 | run_on_node tee /var/lib/astrona-lab/key1.sha256 >/dev/null

run_on_node cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
edit_manifest kube-apiserver 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|; s|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|; s|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|'
wait_for_argument "$node_name" kube-apiserver --encryption-provider-config=/etc/kubernetes/enc/enc.yaml present
wait_for_api

# Write every Secret again, so etcd stores all of them with key1.
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
