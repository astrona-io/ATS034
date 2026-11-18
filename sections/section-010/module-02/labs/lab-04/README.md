---
exam_objectives:
- Use appropriate pod security standards
---
# Remove Host Networking And A hostPath Volume

Repair a Deployment that Baseline rejects because of hostNetwork and a hostPath volume. The graders wait for the rollout, compare the Pod and node addresses and write to the new emptyDir volume. The lab runs in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
