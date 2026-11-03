---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Credential From A ConfigMap Into A Secret

Replace a credential stored in a ConfigMap with a Secret mounted as a read-only file, and remove the ConfigMap.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
