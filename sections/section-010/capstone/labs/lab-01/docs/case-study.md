---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs the `drifter` client Pod. The `dock` namespace enforces Restricted at v1.35 and holds the `scout` Deployment, which has one replica and no Ready Pod. `starfleet` and `outpost` have no Pod Security labels. All workloads run as root with no security settings.
