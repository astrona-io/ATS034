---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Isolate An Untrusted Tenant End To End

Combine namespace controls, a sandbox class, a dedicated node, a network policy and an admission policy for one untrusted tenant.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
