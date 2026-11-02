---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Istio Mutual TLS With PeerAuthentication

Permissive mode lets plain-text clients reach a meshed workload, so it cannot guarantee that traffic is encrypted. Istio has an object for changing that: `PeerAuthentication`. This part explains how Istio sets up mTLS, what the modes mean, how the scopes combine, and what you will observe when you require mTLS for the `starfleet` namespace.

## How the sidecars build an mTLS connection

Istio splits the work between two components. `istiod` is the control plane. It acts as a certificate authority (CA), and it sends configuration to every sidecar. Each Envoy sidecar is part of the data plane. When a Pod starts, its sidecar asks `istiod` for a certificate that names the Pod's identity: a SPIFFE ID of the form `spiffe://cluster.local/ns/<namespace>/sa/<serviceaccount>`. The certificate is short-lived, and `istiod` renews it before it expires.

When the `shuttle` application sends a request to `probe`, its sidecar intercepts the connection and opens a TLS connection to the sidecar of the target Pod. Both sidecars present their certificates and check them against the mesh root of trust. The target sidecar decrypts the traffic and passes plain HTTP to the application over the Pod's local interface.

## The PeerAuthentication object

A **PeerAuthentication** sets which kind of incoming connection a sidecar accepts. The field `spec.mtls.mode` has these values:

- `PERMISSIVE`: accept mTLS and plain text. This is the default.
- `STRICT`: accept only mTLS. A plain-text connection is closed.
- `DISABLE`: accept only plain text. No tunnel is used.
- `UNSET`: inherit the mode from the parent scope.

The scope comes from where you create the object:

- In the root namespace, `istio-system`, with no selector: the whole mesh.
- In an application namespace, with no selector: that namespace.
- In an application namespace, with a `selector`: only the Pods that match the labels.
- With `portLevelMtls` inside a workload policy: single ports.

The most specific policy wins: a workload policy overrides the namespace policy, which overrides the mesh policy. A `PeerAuthentication` controls what the receiving sidecar accepts. It does not choose what the client sends. A client sidecar uses mTLS when the destination supports it, and a `DestinationRule` can change that.

## Require mTLS for starfleet

Before you apply the policy, repeat the request from the client without a sidecar, to see that it works:

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The command returns the line that starts with `version=v1`. Save this as `peerauthentication-namespace-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

Then check the result by sending the same two requests:

```sh
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The first command still returns the `version=v1` line, because `shuttle` has a sidecar and sends mTLS. The second command fails. The sidecar of the target Pod received a plain-text connection and closed it, so `wget` reports a connection error that mentions a reset. The application did not change, the sidecar of the receiver rejected the connection, and the failure takes effect within a few seconds after `istiod` sends the new configuration to the proxies.

Confirm that the policy did not break the Deployment:

```sh
kubectl -n starfleet get pods -l app=probe
```

Both Pods stay `Ready`. Istio rewrites the HTTP readiness probes of injected Pods so that the kubelet, which has no mesh certificate, can still reach them through the sidecar. Without that rewrite, STRICT would mark every Pod as not ready.

## Plan a safe rollout

Move from permissive to strict in this order. Inject sidecars into every workload that talks to the namespace. Watch for plain-text clients in the mesh metrics or access logs. Apply `STRICT` to one namespace, then to the whole mesh with a policy in `istio-system`. Clients outside the mesh, such as an ingress that terminates traffic, a monitoring system or a Job in a namespace without injection, will fail under `STRICT`, so they need a sidecar or a per-port exception.

You now know how to enforce encryption for a namespace and how to predict which callers break. A successful mTLS connection also tells the receiver who the caller is, and the next part uses that fact.

## Common pitfalls

> [!WARNING]
> - **Applying STRICT before the clients have sidecars.** Their plain-text connections are closed.
> - **Creating the object in the wrong namespace.** The namespace of the object sets its scope. A policy in `istio-system` without a selector applies to the whole mesh.
> - **Expecting the policy to change the client.** It controls what the receiving sidecar accepts.
> - **Checking only that the policy exists.** Send a request from a client without a sidecar and confirm that it fails.
> - **Forgetting that Pods start before injection.** Pods created before the namespace label or injection do not have a sidecar until they are restarted.
