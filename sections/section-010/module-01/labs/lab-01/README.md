---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Restricted Pod Admission

Admit a compliant Pod and reject a privileged Pod through the API server.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
