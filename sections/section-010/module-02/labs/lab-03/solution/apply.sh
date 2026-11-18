#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-010-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$(hostname)"
worker_name="$node_name"
namespace="starfleet-034-010-02-03"
source "$lab_directory/bootstrap/helpers.sh"
solution_directory="$lab_directory/solution"
# The kubelet reads Localhost seccomp profiles relative to /var/lib/kubelet/seccomp.
run_on_node install -D -m 0644 /opt/profiles/block-mkdir.json /var/lib/kubelet/seccomp/profiles/block-mkdir.json
# apparmor_parser loads (or replaces) the profile in the kernel in enforce mode.
run_on_node apparmor_parser -r /opt/profiles/k8s-deny-tmp-write
# The security settings of a container cannot change in place, so the Pod is replaced.
kubectl -n "$namespace" delete pod scout --ignore-not-found --wait=true --timeout=120s
kubectl apply -f "$solution_directory/pod-scout.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/scout --timeout=120s
