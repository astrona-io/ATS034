---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A Tenant Node Selector With A ValidatingAdmissionPolicy

Write a ValidatingAdmissionPolicy and a Deny binding that make the node selector `node-restriction.kubernetes.io/tenant=tenant-e` mandatory for new Pods in one namespace, and update the tenant Deployment so that its Pods pass the policy.

The lab runs in its own pinned two-node kind cluster. The graders read the policy and binding, send server-side dry-run Pods (no selector, the wrong tenant, the right tenant, another namespace) and check that the updated `tenant-e-app` Pod runs Ready on the worker. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
