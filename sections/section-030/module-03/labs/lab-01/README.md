---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Dedicate A Node To One Tenant With Taints And Tolerations

Label and taint a worker node for one tenant, run the tenant Deployment there with a node selector and a toleration, and show that a Pod from another namespace without the toleration stays Pending.

The lab runs in its own pinned two-node kind cluster. The graders read the node labels and taints, the Deployment template and the Pod placement, and read the scheduler's `PodScheduled` condition of the stray Pod for the untolerated taint. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
