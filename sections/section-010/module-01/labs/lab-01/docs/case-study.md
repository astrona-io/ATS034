---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `starfleet-034-010-01-01` runs the Pod `shuttle`, and the namespace `outpost-034-010-01-01` runs the Pod `drifter`. Both Pods run `docker.io/library/busybox:1.37.0` with no security settings. Neither namespace has a Pod Security label, so Pod Security Admission checks nothing in them.
