---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Credential From A ConfigMap Into A Secret

Replace a credential stored in a ConfigMap with a Secret mounted as a read-only file, and remove the ConfigMap.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
