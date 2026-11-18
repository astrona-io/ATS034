#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-030-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
config=/etc/containerd/config.toml
if ! sudo grep -q "containerd.runtimes.runsc\]" "$config"; then
  printf '\n[plugins.%s.containerd.runtimes.runsc]\n  runtime_type = "io.containerd.runsc.v1"\n' "'io.containerd.cri.v1.runtime'" | sudo tee -a "$config" >/dev/null
fi
sudo systemctl restart containerd
for attempt in $(seq 1 30); do
  sudo crictl info >/dev/null 2>&1 && break
  sleep 2
done
sudo crictl info | jq -e '.config.containerd.runtimes.runsc.runtimeType == "io.containerd.runsc.v1"' >/dev/null
kubectl -n tenant-b-034-030-02-01 wait --for=condition=Ready pod/scout --timeout=180s
