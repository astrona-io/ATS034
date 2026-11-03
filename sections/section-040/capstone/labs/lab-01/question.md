---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Encrypt And Authorize Pod Traffic

The cluster runs Istio 1.30.5. The namespace `starfleet` has injection enabled and holds the `probe` Deployment (two replicas) with a Service on port 80, and two client Pods with a sidecar: `shuttle` runs as the ServiceAccount `shuttle` and `tender` runs as the ServiceAccount `tender`. The namespace `outpost` holds the client Pod `drifter` without a sidecar. No `PeerAuthentication` and no `AuthorizationPolicy` exist, so every client reaches `probe`. The ConfigMap `cilium-values` in `kube-system` holds the Helm values file for the Cilium network plugin of the production cluster, and encryption is disabled in it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-040" || exit 1
```

Keep this connection selected for the whole task.

## Required result

The security review of the cluster asks for three results. Deliver all of them in one pass, and keep Istio and the existing workloads running with their sidecars.

1. **Encrypted traffic.** A `PeerAuthentication` named `namespace-strict` in `starfleet` requires `STRICT` mTLS for every workload in the namespace. `drifter` must fail to reach `probe` with a connection reset.
2. **Authorized caller.** An `AuthorizationPolicy` named `probe-allow-shuttle` in `starfleet` is an `ALLOW` policy for the `probe` Pods. It allows only the identity of the ServiceAccount `shuttle` in `starfleet`. `shuttle` must reach `probe`, and `tender`, which has a sidecar, must get an HTTP 403 response.
3. **Node encryption values.** The nodes of the production cluster run Linux 5.8, so Cilium can use WireGuard. In the ConfigMap `cilium-values`, the key `values.json` must set `encryption.enabled` to `true`, `encryption.type` to `wireguard` and `encryption.nodeEncryption` to `true`.

## Verify the result

Prove every allowed and every denied path with `wget` from the matching client Pod before you finish. The grader sends the same kind of live requests. Wait a few seconds after you apply a policy, because `istiod` must send the new configuration to the sidecars.
