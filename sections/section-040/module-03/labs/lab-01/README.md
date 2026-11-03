---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prepare IPsec Encryption For Cilium

Create the IPsec key Secret and set the Helm values so that Cilium encrypts node-to-node traffic with IPsec.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. The grader reads the Secret and the values file, because the environment does not run Cilium. Static validation is not live evidence. Runtime verification remains pending.
