---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment To Meet Restricted

Repair a Deployment that Pod Security Admission blocks, so its Pod runs as a non-root user with a read-only root filesystem.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
