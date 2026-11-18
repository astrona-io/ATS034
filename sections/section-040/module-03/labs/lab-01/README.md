---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Enable WireGuard Encryption In Cilium

Turn on Cilium transparent encryption with WireGuard through Helm, restart the agents and prove that traffic between pods on different nodes goes through the `cilium_wg0` interface. The lab runs Cilium 1.20.4 as the network plugin of its own pinned kind cluster. It needs a rootful container engine, because Cilium mounts the BPF filesystem on each node. Python 3 and Helm are required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
