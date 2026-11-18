#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-020-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-034-020-01-03"
source "$lab_directory/bootstrap/helpers.sh"

# A new random 32-byte key for aescbc, written only to a root-owned file.
key="$(head -c 32 /dev/urandom | base64)"
run_on_node mkdir -p /etc/kubernetes/enc /root/backup
run_on_node install -m 600 /dev/null /etc/kubernetes/enc/enc.yaml
run_on_node tee /etc/kubernetes/enc/enc.yaml >/dev/null <<EOF
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
EOF

run_on_node cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
edit_manifest kube-apiserver 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|; s|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|; s|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|'
wait_for_argument "$node_name" kube-apiserver --encryption-provider-config=/etc/kubernetes/enc/enc.yaml present
wait_for_api

# Write every Secret again, so the API server stores it with the new provider.
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
