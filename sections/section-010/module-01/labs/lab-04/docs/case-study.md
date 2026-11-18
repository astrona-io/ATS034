---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `starfleet-034-010-01-04` enforces the Restricted profile, pinned to `v1.35`. It holds the Deployment `scanner` with two replicas. Its Pod template has one container `scanner` that runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity` and has no security settings. The Deployment shows `0/2` Ready Pods.
