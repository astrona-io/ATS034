---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret

Create a typed, immutable Secret and mount it read-only so the API server rejects every change to its data.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
