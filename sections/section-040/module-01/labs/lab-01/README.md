---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS With PeerAuthentication

Require STRICT mutual TLS for one namespace with an Istio PeerAuthentication and prove it with live requests: a client with a sidecar still gets replies, a client without a sidecar is refused. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
