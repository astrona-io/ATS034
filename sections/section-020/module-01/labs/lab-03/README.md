---
exam_objectives:
- Manage Kubernetes secrets
---
# Encrypt Secrets At Rest In etcd

Write an `EncryptionConfiguration`, start the kube-apiserver with it, rewrite the existing Secrets, and prove with the raw etcd data that new and existing Secrets are stored encrypted.

The task and solution use a VM from the pinned `24.04-cks` image with a one-node kubeadm cluster (Kubernetes v1.35.10). The graders read the running kube-apiserver command line and the file mode of the configuration, then read etcd with `etcdctl` inside the etcd container (through `crictl exec`) and check the `k8s:enc:aescbc:v1:` or `k8s:enc:secretbox:v1:` prefix. `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
