---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `hardened-034-010-02-01` enforces the Restricted profile at version v1.35. The `scanner` Deployment in it has one replica and no Ready Pod. Its container uses `busybox`, runs as the image default user and writes the file `/tmp/result` before it sleeps. The `starfleet-034-010-02-01` and `outpost-034-010-02-01` namespaces from the shared environment also exist and must not change.
