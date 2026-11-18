---
exam_objectives:
- Use appropriate pod security standards
---
# Attach A Localhost Seccomp Profile And An AppArmor Profile

A qemu lab: install a Localhost seccomp profile and an AppArmor profile on the node and attach both to the scout Pod. The lab runs in its own VM with a one-node kubeadm cluster.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
