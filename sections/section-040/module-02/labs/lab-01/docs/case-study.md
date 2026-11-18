---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`, together with the mesh-wide PeerAuthentication `default` (mode `STRICT`, no selector). The namespace `starfleet-034-040-02-01` runs the Deployment `probe`, the Service `probe` on port 80 and the client pod `shuttle`. The namespace `depot-034-040-02-01` runs the Deployment `cargo` and the Service `cargo` on port 80. Both namespaces have the label `istio-injection=enabled`, so these pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-01` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. Right now the `drifter` pod is refused by both `probe` and `cargo`.
