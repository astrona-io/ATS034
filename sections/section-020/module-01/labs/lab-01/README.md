---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumer

Replace a disposable credential and verify both delivery paths use the new value.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
