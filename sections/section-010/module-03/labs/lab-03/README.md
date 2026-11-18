---
exam_objectives:
- Use appropriate pod security standards
---
# Admit A Node Agent And Protect Pod Security Labels

Exempt a node log agent with a hostPath volume by enforcing Privileged with Baseline warn and audit, and remove the RBAC binding that lets a deployment account change namespace labels. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
