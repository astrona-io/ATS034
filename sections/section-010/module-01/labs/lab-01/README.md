---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Restricted Pod Admission

Admit a compliant Pod and reject a privileged Pod through the API server.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
