#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-034-lab-030-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
config=/etc/containerd/config.toml
# The image installs gVisor and registers the runsc handler. The lab starts
# with the binaries in place but without the handler table, so remove the
# runsc tables from the containerd configuration and restart containerd.
sudo python3 - "$config" <<'PY'
import re
import sys
path = sys.argv[1]
text = open(path).read()
table = re.compile(r"^\[plugins\.'io\.containerd\.cri\.v1\.runtime'\.containerd\.runtimes\.runsc(\.[^\]]*)?\]\n(?:(?!\[).*\n?)*", re.M)
text = table.sub('', text).rstrip('\n') + '\n'
open(path, 'w').write(text)
PY
sudo systemctl restart containerd
for attempt in $(seq 1 30); do
  sudo crictl info >/dev/null 2>&1 && break
  sleep 2
done
if sudo crictl info | jq -e '.config.containerd.runtimes | has("runsc")' >/dev/null; then
  printf 'containerd still reports the runsc handler\n' >&2
  exit 1
fi
command -v runsc >/dev/null
command -v containerd-shim-runsc-v1 >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-034-030-02-01 wait --for=condition=Ready pod/shuttle --timeout=180s
