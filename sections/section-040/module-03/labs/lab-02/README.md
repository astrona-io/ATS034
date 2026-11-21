---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Rotate The Cilium IPsec Key

Rotate the IPsec key of Cilium transparent encryption: write a new key with a higher SPI into the Secret `cilium-ipsec-keys`, wait for every agent to load it and prove that the kernels use the new security associations while traffic keeps flowing. It has three outcomes, one point each: `key-rotated` (the Secret holds a new key with an SPI above 3), `agents-use-new-key` (every agent reports IPsec with no errors, each node has a security association with the new SPI, and `shuttle` still gets `probe-reply`) and `wire-uses-new-spi` (a capture on `eth0` of the worker node, taken while `shuttle` sends requests to `probe`, sees ESP packets with the new SPI only, none with SPI 3, and never the plain text `probe-reply`). The `wire-uses-new-spi` grader runs a short raw-socket capture with `python3` inside the worker node container through the container engine (`node_exec`), so it does not depend on the netshoot image; that image (`docker.io/nicolaka/netshoot:v0.14`) is preloaded only for the learner's `kubectl debug node` capture. The lab runs Cilium 1.20.4 with IPsec in its own pinned kind cluster. It needs a rootful container engine, because Cilium mounts the BPF filesystem on each node. Python 3 is required on the grading host, and the reference solution uses `openssl`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
