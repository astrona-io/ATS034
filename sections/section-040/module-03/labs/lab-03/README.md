---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Cilium Agent That Did Not Load WireGuard

Find the Cilium agent that still reports `Encryption: Disabled` after WireGuard was turned on in the Helm release, record its node in a ConfigMap and restart the agents so that every node encrypts its traffic. The setup turns WireGuard on with `helm upgrade` and restarts only the agent on the control-plane node, so the agent on the worker node keeps its old settings. The lab runs Cilium 1.20.4 as the network plugin of its own pinned kind cluster. It needs a rootful container engine, because Cilium mounts the BPF filesystem on each node. Python 3 and Helm are required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
