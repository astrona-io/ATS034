---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To Strict mTLS With One Exception

Require mTLS for the whole `starfleet-034-040-02-01` namespace and keep the `legacy` workload reachable for the client without a sidecar.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
