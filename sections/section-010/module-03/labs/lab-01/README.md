---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage Pod Security Labels On Two Namespaces

Label two namespaces with different Pod Security profiles and prove the effect without disturbing the running Pods.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
