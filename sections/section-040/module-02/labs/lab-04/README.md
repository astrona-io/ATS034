---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Wrong Principal In An AuthorizationPolicy

Read the SPIFFE ID from the certificate of a client sidecar, then fix an `ALLOW` AuthorizationPolicy whose principal names the wrong ServiceAccount. Live requests prove that the `shuttle` client is admitted again and that a second meshed client in the same namespace, the `drifter` with ServiceAccount `default`, is still refused with HTTP 403. A static check makes sure that the policy still names exactly the `shuttle` principal, so deleting the policy, a `namespaces` rule or a wildcard principal fails. The lab runs Istio 1.30.5 in its own pinned kind cluster. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
