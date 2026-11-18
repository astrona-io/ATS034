# Keeping Credentials Out Of Manifests Playground

This ungraded playground is a qemu VM (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`) with a one-node kubeadm cluster. `bootstrap/setup.sh` runs inside the VM: it initialises the cluster, gives the `student` user the admin kubeconfig, and creates the `starfleet` and `outpost` namespaces with the `shuttle` and `drifter` pods, the Secret `practice-token` and the ConfigMap `legacy-settings`.

A VM is used because the audit reading edits the real kube-apiserver static pod manifest and reads the real audit log file on the node. The configuration has no submission or grading fields. Test the start with `scripts/ci/test-playground.sh sections/section-020/module-03/playground`.
