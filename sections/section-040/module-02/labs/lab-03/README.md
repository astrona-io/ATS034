---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Client TLS Setting That Breaks STRICT

Require STRICT mutual TLS for a namespace, then find and fix the DestinationRule that makes the meshed client send plain text and fail. Live requests prove that STRICT stays on and the meshed client works again over mutual TLS. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
