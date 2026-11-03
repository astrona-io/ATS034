---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Summary

A `PeerAuthentication` sets which connections a receiving sidecar accepts: `PERMISSIVE` accepts mTLS and plain text, `STRICT` accepts only mTLS, `DISABLE` accepts only plain text, and `UNSET` inherits. The scope comes from the namespace of the object and its selector. An object in `istio-system` without a selector covers the mesh, and a selector with `portLevelMtls` narrows it to ports that the workload listens on. The narrowest policy replaces the wider ones, so an exception for one workload does not weaken the rest.

A safe migration injects sidecars first, finds the plain-text clients with the `connection_security_policy` label of the request metric, enforces `STRICT` for one namespace and grants narrow `PERMISSIVE` exceptions where a client cannot change. Exceptions are reviewed and removed when the client is fixed.

Each sidecar gets a short-lived certificate from the certificate authority in `istiod`. `pilot-agent` creates the key in the Pod, proves its identity with the ServiceAccount token, and renews the certificate before it expires, by default after about 24 hours. The certificate holds a SPIFFE ID of the form `spiffe://cluster.local/ns/<namespace>/sa/<serviceaccount>`, which is what authorization rules use as the principal. Changing the root CA needs a period in which sidecars trust both roots.

A policy is a declaration, so verification needs an allowed request, a denied request, handshake counters in the proxy and, when needed, the request metric or a packet capture. A client-side `DestinationRule` that disables TLS conflicts with a `STRICT` server and produces errors such as HTTP 503 even though both Pods have sidecars.

<!-- astrona:playground:destroy -->
