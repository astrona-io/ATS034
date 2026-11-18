---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

The isolated environment runs Istio 1.30.5 and has the namespace `starfleet-034-040-02-01` with injection enabled. It holds the `probe` Deployment (two replicas) and the `legacy` Deployment (one replica), each with a Service on port 80, and the client Pod `shuttle` with a sidecar. The namespace `outpost-034-040-02-01` holds the client Pod `drifter` without a sidecar. No `PeerAuthentication` exists, so every request works.
