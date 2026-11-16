---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage Pod Security Labels On Two Namespaces

Label two namespaces with different Pod Security profiles and prove the effect without disturbing the running Pods.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
