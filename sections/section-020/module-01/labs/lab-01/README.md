---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumer

Replace a disposable credential and verify both delivery paths use the new value.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
