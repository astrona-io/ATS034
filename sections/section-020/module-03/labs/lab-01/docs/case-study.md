---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The ConfigMap `legacy-settings` in `starfleet` holds the key `credential` with the disposable value `disposable-v1` and the key `greeting`. Anyone who can read ConfigMaps can read that credential. The required result has not been configured.
