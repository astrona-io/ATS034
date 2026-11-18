---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

Three namespaces have no Pod Security labels:

- `bridge-034-010-03-01` runs the Deployment `bridge`.
- `starfleet-034-010-03-01` runs the Deployment `shuttle`.
- `outpost-034-010-03-01` runs the Pod `drifter`.

All three run `docker.io/library/busybox:1.37.0` with the command `sleep infinity`. You do not know yet which of them meet the Restricted profile.
