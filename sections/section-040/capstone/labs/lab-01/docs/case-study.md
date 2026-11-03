---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

The cluster runs Istio 1.30.5. The namespace `starfleet` has injection enabled and holds the `probe` Deployment (two replicas) with a Service on port 80, and two client Pods with a sidecar: `shuttle` runs as the ServiceAccount `shuttle` and `tender` runs as the ServiceAccount `tender`. The namespace `outpost` holds the client Pod `drifter` without a sidecar. No `PeerAuthentication` and no `AuthorizationPolicy` exist, so every client reaches `probe`. The ConfigMap `cilium-values` in `kube-system` holds the Helm values file for the Cilium network plugin of the production cluster, and encryption is disabled in it.
