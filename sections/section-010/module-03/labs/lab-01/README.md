---
exam_objectives:
- Use appropriate pod security standards
---
# Roll Out Restricted Using A Dry-Run Inventory

Use a server-side dry run of the enforce label as an inventory, enforce Restricted where every running Pod complies and warn on Restricted everywhere else. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
