---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Certificates And Workload Identity

Strict mode only works when every sidecar holds a valid certificate. If certificates expire or come from the wrong root, mTLS fails even though the policy is correct. This part explains how a sidecar gets its certificate, what the certificate says, how it renews and how to look at it.

## How a workload gets a certificate

`istiod` contains a certificate authority (CA), which is a service that signs certificates. Each Pod with a sidecar also runs `pilot-agent`, a process in the `istio-proxy` container that talks to `istiod`. The steps are:

1. `pilot-agent` creates a private key inside the Pod and builds a certificate signing request (CSR).
2. It sends the CSR to `istiod` together with the Kubernetes ServiceAccount token of the Pod.
3. `istiod` checks the token with the Kubernetes API server, signs the certificate and returns it.
4. `pilot-agent` hands the certificate and key to Envoy through the secret discovery service (SDS), a gRPC API for secrets. The private key never leaves the Pod and is never written to a Secret.

Because the proof of identity is the ServiceAccount token, the identity is tied to the ServiceAccount of the Pod and not to its IP address or name.

## What the certificate contains

The certificate carries a SPIFFE ID in its subject alternative name (SAN) field. SPIFFE is a standard that names a workload identity as a URI. In Istio the ID has this form:

```text
spiffe://<trust-domain>/ns/<namespace>/sa/<serviceaccount>
```

The default trust domain is `cluster.local`. A `shuttle` Pod in `starfleet` that runs as ServiceAccount `default` has the ID `spiffe://cluster.local/ns/starfleet/sa/default`. An `AuthorizationPolicy` writes the same identity without the prefix, as the principal `cluster.local/ns/starfleet/sa/default`. Two Pods with the same ServiceAccount have the same identity, so use one ServiceAccount per role when you want rules for individual workloads.

## Lifetime and rotation

Workload certificates are short-lived. The default lifetime is 24 hours. `pilot-agent` requests a new certificate before the old one expires, and Envoy starts using it without a restart, so connections keep working. Short life limits the damage of a stolen key: it stops working within a day, and there is no revocation list to maintain.

The root of trust is the CA certificate that signs the workload certificates. By default `istiod` creates a self-signed root and stores it in the Secret `istio-ca-secret` in `istio-system`. A production cluster often plugs in its own CA by creating a Secret called `cacerts` in `istio-system` that holds an intermediate certificate, so all certificates chain to the company root. When you change the root, sidecars must trust both the old and the new root during the change, or connections fail.

## Look at the certificate of a sidecar

Envoy has an administration interface, and `pilot-agent` can query it from inside the `istio-proxy` container. Ask the `shuttle` sidecar for its certificates:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet exec shuttle -c istio-proxy -- pilot-agent request GET certs
```

The command prints JSON with two kinds of entries: the certificate chain of this workload and the CA certificate it trusts. Look for the `serial_number`, the `valid_from` and `expiration_time` fields, and the `subject_alt_names` entry that holds the SPIFFE ID. The validity window should span about 24 hours. Confirm which ServiceAccount the Pod runs as, and compare it with the ID in the output:

```sh
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

The name printed is the last part of the SPIFFE ID. Last, check that the root certificate in the mesh comes from the Secret that `istiod` manages:

```sh
kubectl -n istio-system get secret
kubectl -n starfleet get configmap istio-ca-root-cert
```

The Secret list shows whether the mesh uses the self-signed `istio-ca-secret` or a plugged-in `cacerts`. The ConfigMap `istio-ca-root-cert` exists because `istiod` copies the root certificate into every namespace, and sidecars load it to validate peers. You now know what a sidecar presents when it opens an mTLS connection. The remaining task is to prove that a real connection uses it, which is the next part.

## Common pitfalls

> [!WARNING]
> - **Sharing one ServiceAccount between roles.** All Pods then have one identity and a rule cannot separate them.
> - **Looking for the private key in a Secret.** It lives only in the memory of the Pod.
> - **Changing the root CA without an overlap.** Sidecars that trust only one root reject the others.
> - **Ignoring clock differences.** A node clock far from real time makes a valid certificate look expired or not yet valid.
> - **Assuming a restart is needed for renewal.** Rotation is automatic and does not restart the Pod.
