---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Isolate A Tenant Namespace And Remove Its Token

Put a default-deny NetworkPolicy and one narrow egress allowance on a tenant namespace, and stop a Pod from receiving a ServiceAccount token it does not use.

The lab runs in its own pinned kind cluster with Calico, the network plugin that enforces NetworkPolicy. The graders read the policies and the ServiceAccount, send bounded live HTTP requests from the tenant Pod and from a control Pod, and list the token directory inside the running Pod. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
