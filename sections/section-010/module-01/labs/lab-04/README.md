---
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment That Pod Security Admission Blocks

Find the FailedCreate event of a Deployment that Pod Security Admission blocks, then repair its Pod template so the rollout completes under Restricted. The graders check the rollout and read /proc/1/status in each Pod. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
