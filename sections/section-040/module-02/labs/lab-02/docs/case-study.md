---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-02` has the label `istio-injection=enabled` and runs the Deployments `probe` and `legacy` (one replica each, labels `app: probe` and `app: legacy`, HTTP on container port 8080), the Services `probe` and `legacy` on port 80, and the client pod `shuttle`. These pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-02` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists, so every request works.
