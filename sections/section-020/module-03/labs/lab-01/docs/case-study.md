---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The `starfleet-034-020-03-01` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The ConfigMap `legacy-settings` in `starfleet-034-020-03-01` holds the key `credential` with the disposable value `disposable-v1` and the key `greeting`. Anyone who can read ConfigMaps can read that credential. The required result has not been configured.
