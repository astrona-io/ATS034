# Harden Container Privileges Playground

This ungraded playground is a qemu VM (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`) with a one-node kubeadm cluster. `bootstrap/setup.sh` runs inside the VM: it initialises the cluster, gives the `student` user the admin kubeconfig, places the seccomp profile `block-mkdir.json` and the AppArmor profile `k8s-deny-tmp-write` in `/opt/profiles`, and creates the `starfleet`, `outpost` and `hardened` namespaces with their workloads. `docs/overview.md` is the guide the learner sees.

A VM is used because the seccomp and AppArmor reading installs `Localhost` profiles on the node, and a kind node uses the kernel of the machine that runs Podman, which often has no AppArmor. The configuration has no submission or grading fields. Test the start with `scripts/ci/test-playground.sh sections/section-010/module-02/playground`.
