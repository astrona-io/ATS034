---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Restricted With Namespace Labels

Label two namespaces so Pod Security Admission enforces Baseline in one and Restricted in the other. The graders send server-side dry-run Pods and check which ones the API server rejects. It runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
