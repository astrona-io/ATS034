---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment To Meet Restricted

Repair a Deployment that Pod Security Admission blocks, so its Pod runs as a non-root user with a read-only root filesystem.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
