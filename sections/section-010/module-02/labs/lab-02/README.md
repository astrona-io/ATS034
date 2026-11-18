---
exam_objectives:
- Use appropriate pod security standards
---
# Drop All Capabilities And Block Privilege Escalation

Drop all capabilities and set allowPrivilegeEscalation to false on a Pod that keeps running as root. The graders read /proc/1/status and try a real chown. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
