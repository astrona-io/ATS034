---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Override Mesh-Wide STRICT For One Namespace

Use the precedence of Istio PeerAuthentication policies: keep a mesh-wide STRICT policy and add a namespace policy that sets PERMISSIVE for one namespace only. Live requests prove that the override works in one namespace and that a second namespace stays STRICT. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
