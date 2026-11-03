---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The `starfleet` namespace runs the `probe` Deployment, the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs `drifter`. The ServiceAccount `reader` in `starfleet` is bound by the RoleBinding `reader-secrets` to the Role `secret-reader`. That Role allows `get`, `list` and `watch` on every Secret in the namespace. The Secret `practice-token` exists. The ConfigMap `legacy-credentials` holds the disposable credential `disposable-v3` in plain text. No other Secret exists.
