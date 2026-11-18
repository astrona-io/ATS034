---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Limit A Tenant User To One Namespace With RBAC

Replace a cluster-wide `edit` binding with a namespaced Role and RoleBinding, and prove with impersonated requests that the user can work in one namespace, cannot touch Secrets and is refused everywhere else.

The lab runs in its own pinned kind cluster. The graders send real requests as the user `alice` (server-side dry runs for writes) and read the bindings. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
