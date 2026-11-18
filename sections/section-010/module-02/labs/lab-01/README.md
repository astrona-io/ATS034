---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Deployment As A Non-Root User

Change a Deployment so its process runs as user 1000 with runAsNonRoot set. The graders run id in each probe Pod and send a request through the Service from shuttle. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
