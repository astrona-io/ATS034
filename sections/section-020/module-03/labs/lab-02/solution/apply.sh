#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-020-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The VM is the only node: control plane and worker. kubeadm names it after
# the host name, which differs under `astrona test`.
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-034-020-03-02"
source "$lab_directory/bootstrap/helpers.sh"

run_on_node mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit /root/backup
run_on_node install -m 600 "$lab_directory/solution/policy-audit.yaml" /etc/kubernetes/audit/policy.yaml
run_on_node cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
edit_manifest kube-apiserver 's|^    - kube-apiserver$|&\n    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n    - --audit-log-path=/var/log/kubernetes/audit/audit.log\n    - --audit-log-maxage=7\n    - --audit-log-maxbackup=2|; s|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/audit/policy.yaml\n      name: audit-policy\n      readOnly: true\n    - mountPath: /var/log/kubernetes/audit\n      name: audit-log|; s|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/audit/policy.yaml\n      type: File\n    name: audit-policy\n  - hostPath:\n      path: /var/log/kubernetes/audit\n      type: DirectoryOrCreate\n    name: audit-log|'
wait_for_argument "$node_name" kube-apiserver --audit-log-path=/var/log/kubernetes/audit/audit.log present
wait_for_api

# The access that the task asks to record: one get as the ServiceAccount.
kubectl -n "$namespace" get secret probe-credentials --as "system:serviceaccount:$namespace:auditor" -o name
