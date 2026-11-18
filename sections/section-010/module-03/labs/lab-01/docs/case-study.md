---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

Neither `starfleet-034-010-03-01` nor `outpost-034-010-03-01` has Pod Security labels. The `starfleet-034-010-03-01` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost-034-010-03-01` namespace runs the `drifter` client Pod. All of these Pods run as root and have no security settings.
