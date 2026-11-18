---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-01-02` has the label `istio-injection=enabled` and runs the Deployment `probe` (one replica, label `app: probe`, HTTP on container port 8080), the Service `probe` on port 80, and the client pods `shuttle` and `tender`. Each pod runs under a ServiceAccount with its own name (`probe`, `shuttle`, `tender`) and has an `istio-proxy` sidecar. The client pods contain BusyBox `wget`. No AuthorizationPolicy and no PeerAuthentication exist.
