---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumers

Rotate a disposable Secret value and prove the two refresh paths: the kubelet updates a mounted Secret volume in the same running pod, while an environment variable changes only in a recreated pod.

The lab runs in its own pinned kind cluster. The setup records the starting pod UIDs in the ConfigMap `rotation-start`. The graders compare those UIDs, wait at most 90 seconds for the kubelet to refresh the volume, and compare the values inside the containers. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
