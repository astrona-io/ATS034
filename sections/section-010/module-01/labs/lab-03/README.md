---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Preview Restricted

Enforce Baseline and warn and audit with Restricted, all pinned to v1.35. The graders send server-side dry-run Pods and read the rejection and the warning that the API server returns. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
