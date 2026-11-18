#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-030-01-04}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
# The image registers the runsc handler in containerd. The lab needs it, so
# stop early when it is missing instead of grading a broken start.
sudo crictl info | jq -e '[.. | objects | .runsc? // empty | .runtimeType] | index("io.containerd.runsc.v1") != null' >/dev/null
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-030-01-04 wait --for=condition=Ready pod/shuttle --timeout=180s
