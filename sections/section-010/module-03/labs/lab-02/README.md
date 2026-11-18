---
exam_objectives:
- Use appropriate pod security standards
---
# Set Cluster-Wide Pod Security Defaults And An Exemption

A qemu lab: set cluster-wide Pod Security defaults with an AdmissionConfiguration file on the API server and exempt one namespace. The lab runs in its own VM with a one-node kubeadm cluster.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
