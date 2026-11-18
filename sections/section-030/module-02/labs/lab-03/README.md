---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A RuntimeClass With A ValidatingAdmissionPolicy

Write a ValidatingAdmissionPolicy and a Deny binding that make `runtimeClassName: sandboxed` mandatory for new Pods in one namespace, and recreate an existing Pod that the policy does not touch on its own.

The lab runs in its own pinned kind cluster. The RuntimeClass `sandboxed` uses the `runc` handler there, and the task says so. The graders read the policy and binding, send server-side dry-run Pods to prove the denial in the untrusted namespace, the admission of a sandboxed Pod and the unchanged trusted namespace, and check that `job-runner` runs Ready with the class. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
