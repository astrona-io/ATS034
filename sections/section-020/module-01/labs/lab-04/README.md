---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate The Encryption-At-Rest Key

Add a new `aescbc` key in front of the old one, restart the kube-apiserver, rewrite every Secret, then remove the old key and restart again, and prove with the raw etcd data that every Secret is stored with the new key.

The task and solution use a VM from the pinned `24.04-cks` image with a one-node kubeadm cluster (Kubernetes v1.35.10). `bootstrap/setup.sh` turns on encryption with a random `key1`, rewrites every Secret with it and stores the SHA-256 hash of the `key1` value in `/var/lib/astrona-lab/key1.sha256` (root only), so the graders can recognize the old key under any name. The graders parse `/etc/kubernetes/enc/enc.yaml` with PyYAML on the VM, read the running kube-apiserver command line, compare its start time with the file's modification time, and read etcd with `etcdctl` inside the etcd container (through `crictl exec`) to check the `k8s:enc:aescbc:v1:key2:` prefix. `solution/apply.sh` restarts the kube-apiserver with `crictl stop`, because a change to the EncryptionConfiguration does not change the static pod manifest.

`vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
