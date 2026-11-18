---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Rotate The Cilium IPsec Key

Rotate the IPsec key of Cilium transparent encryption: write a new key with a higher SPI into the Secret `cilium-ipsec-keys`, wait for every agent to load it and prove that the kernels use the new security associations while traffic keeps flowing. The lab runs Cilium 1.20.4 with IPsec in its own pinned kind cluster. It needs a rootful container engine, because Cilium mounts the BPF filesystem on each node. Python 3 is required on the grading host, and the reference solution uses `openssl`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
