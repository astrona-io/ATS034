#!/usr/bin/env bash
# Runs inside the playground VM as the astrona user. astrona copies only this
# file into the VM, so the start objects are inlined below.
set -euo pipefail
cluster="astro-ats-034-playground-030-02"
# The learner logs in as student, so student gets the admin kubeconfig too.
kube_users=(--user "$(id -un)")
getent passwd student >/dev/null && kube_users+=(--user student)
sudo /usr/local/sbin/astrona-kubeadm-init --cluster-name "$cluster" "${kube_users[@]}"
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# The module parts need the runsc handler that the image registers in containerd.
sudo crictl info | jq -e '.config.containerd.runtimes.runsc.runtimeType == "io.containerd.runsc.v1"' >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl apply -f - <<'MANIFEST'
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-b
MANIFEST
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/tenant-b --timeout=60s
