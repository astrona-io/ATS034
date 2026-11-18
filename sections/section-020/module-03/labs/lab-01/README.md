---
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Leaked Credential Into A Secret

Move a credential from a literal environment variable in a Deployment and from a ConfigMap into a Secret, and remove the plain copies.

The lab runs in its own pinned kind cluster. The graders read the Secret, scan every literal `env` value of the Deployment's pod template, require a `secretKeyRef`, a finished rollout and a match inside the running container, and check that the ConfigMap is gone. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
