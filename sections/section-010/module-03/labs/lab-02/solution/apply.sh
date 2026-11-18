#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-010-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-034-010-03-02"
source "$lab_directory/bootstrap/helpers.sh"
solution_directory="$lab_directory/solution"
config_file=/etc/kubernetes/pod-security/admission.yaml
run_on_node install -D -m 0644 "$solution_directory/admission.yaml" "$config_file"
# One edit adds the flag, the volume mount and the hostPath volume, so the
# kubelet restarts the API server once.
edit_manifest kube-apiserver '/^    - kube-apiserver$/a\    - --admission-control-config-file='"$config_file"'
/^    volumeMounts:$/a\    - mountPath: /etc/kubernetes/pod-security\n      name: pod-security\n      readOnly: true
/^  volumes:$/a\  - hostPath:\n      path: /etc/kubernetes/pod-security\n      type: DirectoryOrCreate\n    name: pod-security'
wait_for_argument "$node_name" kube-apiserver "--admission-control-config-file=$config_file" present
wait_for_api
