---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Allow One Workload Identity With AuthorizationPolicy

Write an Istio AuthorizationPolicy that admits one caller by the workload identity in its mutual TLS certificate, and prove with live requests that a second caller with a sidecar gets HTTP 403. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
