---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-03` has the label `istio-injection=enabled` and runs the Deployment `probe`, the Service `probe` on port 80 and the client pod `shuttle`. These pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-03` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists. Other Istio objects from earlier work may still exist in `starfleet-034-040-02-03`.
