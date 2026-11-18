---
exam_objectives:
- Manage Kubernetes secrets
---
# Deliver A Secret As An Environment Variable And A File

Create one pod that receives the Secret `practice-token` as an environment variable and as a file with mode `0400`, and prove both paths inside the running container.

The lab runs in its own pinned kind cluster. The graders read the pod spec, run a compare command in the container and read the file mode with `stat -L`. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
