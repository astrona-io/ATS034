---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-01-01` has the label `istio-injection=enabled` and runs the Deployment `probe` (one replica, HTTP on container port 8080), the Service `probe` on port 80 and the client pod `shuttle`. Each of these pods has an `istio-proxy` sidecar. The namespace `outpost-034-040-01-01` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists, so the probe sidecar accepts both mutual TLS and plain text.
