---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prepare IPsec Encryption For Cilium

Create the IPsec key Secret and set the Helm values so that Cilium encrypts node-to-node traffic with IPsec.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. The grader reads the Secret and the values file, because the environment does not run Cilium.
