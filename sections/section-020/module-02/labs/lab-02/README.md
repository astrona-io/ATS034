---
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret

Create a typed, immutable Secret and mount it read-only, then prove that the API server rejects every change to its data.

The lab runs in its own pinned kind cluster. The graders read the Secret, send a patch that must be rejected with an `immutable` error, and compare the mounted files inside the pod. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
