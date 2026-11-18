---
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The namespace `starfleet-034-020-03-01` runs the Deployment `scout`, whose pod template sets `API_TOKEN` with a literal value. The ConfigMap `legacy-settings` holds a second plain copy of the same disposable token. The Secret `scout-credentials` does not exist yet.
