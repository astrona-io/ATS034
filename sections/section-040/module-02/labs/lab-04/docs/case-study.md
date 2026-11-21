---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-04` has the label `istio-injection=enabled` and runs the Deployment `probe` (label `app: probe`), the Service `probe` on port 80 and the client pods `shuttle` and `drifter`. Every pod has an `istio-proxy` sidecar. The `shuttle` pod runs as the ServiceAccount `shuttle`, and the `drifter` pod runs as the ServiceAccount `default`. The client pods contain BusyBox `wget`. The AuthorizationPolicy `probe-allow-shuttle` selects the `probe` pods with the action `ALLOW`, and both clients get `403 Forbidden` from the `probe` Service.
