---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Lock Down Secret Handling For One Workload

Combine a typed immutable Secret, a pull credential, a read-only mounted file, a least-privilege Role and the removal of a leaked credential.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
