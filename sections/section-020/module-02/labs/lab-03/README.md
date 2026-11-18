---
exam_objectives:
- Manage Kubernetes secrets
---
# Limit Secret Access To One Named Secret With RBAC

Write a Role with `resourceNames` so a ServiceAccount can get exactly one Secret, and prove the limit with a matrix of `kubectl auth can-i` checks.

The lab runs in its own pinned kind cluster. The graders ask the API server as the ServiceAccount: one real `get` must succeed, a `get` of the other Secret must be forbidden, and `list`, `watch`, `create`, `update` and `delete` must be denied. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
