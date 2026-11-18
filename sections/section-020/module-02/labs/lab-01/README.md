---
exam_objectives:
- Manage Kubernetes secrets
---
# Give A ServiceAccount An Image Pull Secret

Create a `kubernetes.io/dockerconfigjson` Secret, attach it to a ServiceAccount, and prove that the API server copies it into a new pod.

The lab runs in its own pinned kind cluster. The graders decode the `.dockerconfigjson` key, read the ServiceAccount, and read the pod's stored `spec.imagePullSecrets`. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
