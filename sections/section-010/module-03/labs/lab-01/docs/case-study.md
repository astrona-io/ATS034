---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

Neither `starfleet` nor `outpost` has Pod Security labels. The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs the `drifter` client Pod. All of these Pods run as root and have no security settings.
