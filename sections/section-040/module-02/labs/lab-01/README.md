---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To Strict mTLS With One Exception

Require mTLS for the whole `starfleet` namespace and keep the `legacy` workload reachable for the client without a sidecar.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
