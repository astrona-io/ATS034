---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Starting Environment

The isolated environment has two healthy probe replicas in `starfleet`, an internal Service, a `shuttle` client and a `drifter` client in `outpost`. The `untrusted` namespace, the sandbox class, the node separation and the admission policy do not exist.

Combine namespace controls, a sandbox class, a dedicated node, a network policy and an admission policy for one untrusted tenant.
