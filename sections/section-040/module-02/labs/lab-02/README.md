---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To STRICT With One Exception

Move a namespace from PERMISSIVE to STRICT mutual TLS while one workload keeps accepting plain text from a client that has no sidecar. Live requests prove the namespace policy and the workload exception. Both a workload-wide PERMISSIVE policy and a port-level exception pass. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
