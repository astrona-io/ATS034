# Keeping Credentials Out Of Manifests Playground

This ungraded playground is a qemu VM (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`) with a one-node kubeadm cluster. `bootstrap/setup.sh` runs inside the VM: it initialises the cluster, gives the `student` user the admin kubeconfig, and creates the `starfleet` and `outpost` namespaces with the `shuttle` and `drifter` pods, the Secret `practice-token` and the ConfigMap `legacy-settings`.

A VM is used because the audit reading edits the real kube-apiserver static pod manifest and reads the real audit log file on the node. The configuration has no submission or grading fields.

`testing/smoke.sh` runs inside the VM as `student`. It takes the YAML blocks straight from the module pages and runs the page commands (the credential in the ConfigMap, the literal environment variable, the `last-applied-configuration` annotation, the Secret mounted as a file, the audit policy and the edited kube-apiserver static pod manifest, the audit events of the `auditor` ServiceAccount, and the `kubectl auth can-i --list` review). It fails when a result differs from what the page says. Run it with `scripts/ci/test-playground.sh sections/section-020/module-03/playground`. That script copies only the module pages and `testing/` into the VM, so the steps of `docs/overview.md` that need its YAML block are skipped there.
