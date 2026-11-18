---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Cap A Tenant With ResourceQuota And LimitRange

Give a namespace a ResourceQuota and a LimitRange, then prove with a real Deployment that the defaults reach the Pods and that the quota rejects the third replica.

The lab runs in its own pinned kind cluster. The graders read the quota and the LimitRange, send a server-side dry run of an oversized Pod, and read the running Pods and the Deployment status. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
