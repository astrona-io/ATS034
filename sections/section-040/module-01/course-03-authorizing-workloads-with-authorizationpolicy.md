---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Authorizing Workloads With AuthorizationPolicy

Encryption answers whether a connection is private. It does not answer whether the caller is allowed to make the request. With strict mTLS, the receiving sidecar knows the caller's certificate identity, and an `AuthorizationPolicy` can use it. This part explains how the policy is evaluated and tests it with a second client that has its own ServiceAccount.

## Identity comes from the ServiceAccount

The certificate that `istiod` issues to a sidecar carries the SPIFFE ID of the Pod's ServiceAccount. In the `starfleet` namespace, a Pod that runs as the ServiceAccount `bridge` has the identity `cluster.local/ns/starfleet/sa/bridge`. Istio calls this value the **principal** of the request. The principal is only available when the connection uses mTLS. A plain-text connection has no principal, so a rule that names a principal can never match it.

## How the policy is evaluated

An **AuthorizationPolicy** has a `selector` for the target Pods, an `action` and a list of `rules`. The sidecar of each target Pod evaluates the policies in this order:

1. If any `CUSTOM` policy matches, the external authorizer decides.
2. If any `DENY` policy matches the request, the request is rejected.
3. If no `ALLOW` policy exists for the workload, the request is allowed.
4. If an `ALLOW` policy exists and one of its rules matches, the request is allowed.
5. Otherwise the request is rejected.

Step 3 and step 5 together matter most. A workload with no authorization policy allows everything. The first `ALLOW` policy for a workload changes it to default deny: everything that no rule matches is rejected. A policy with `action: ALLOW` and an empty spec allows nothing.

A rule has `from` (the source: `principals`, `namespaces`, `ipBlocks`), `to` (the operation: `methods`, `paths`, `ports`) and `when` (extra conditions). Conditions inside one rule are combined with AND. Separate rules are combined with OR.

## Allow only one caller

Create a ServiceAccount and a client Pod that uses it. Save this as `bridge-client.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bridge
  namespace: starfleet
---
apiVersion: v1
kind: Pod
metadata:
  name: bridge-client
  namespace: starfleet
spec:
  serviceAccountName: bridge
  containers:
  - name: client
    image: busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply it and wait for the Pod:

```sh
kubectl apply -f bridge-client.yaml
kubectl -n starfleet wait --for=condition=Ready pod/bridge-client --timeout=120s
```

The namespace has injection enabled, so the Pod has the `client` container and the `istio-proxy` container. Make sure that mTLS is required, so that every caller has a principal. Save this as `strict.yaml`:

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
kubectl apply -f strict.yaml
```

Then save this as `allow-bridge.yaml`. It allows only the `bridge` principal to send GET requests to the `probe` Pods:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-bridge
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/starfleet/sa/bridge"]
    to:
    - operation:
        methods: ["GET"]
```

Apply it:

```sh
kubectl apply -f allow-bridge.yaml
```

Then check the result from both clients:

```sh
kubectl -n starfleet exec bridge-client -c client -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet.svc.cluster.local/
```

The first command returns the `version=v1` line. The second command fails with an HTTP 403 error, and the response body from the sidecar is `RBAC: access denied`. Both clients used mTLS and both were authenticated. The sidecar of `probe` authorized only one of them, because `shuttle` runs as the default ServiceAccount and its principal is not in the rule. The failure is an HTTP error from the target sidecar, so it differs from the connection reset that a plain-text client gets under strict mTLS.

## Pick the right layer

Use `PeerAuthentication` to decide how connections are secured. Use `AuthorizationPolicy` to decide who may call what. Namespaces and Kubernetes `NetworkPolicy` still matter: a NetworkPolicy works at layers 3 and 4 and applies to every Pod, including those without a sidecar. An `AuthorizationPolicy` is enforced only by sidecars, so a workload without a sidecar is not covered by it.

## Common pitfalls

> [!WARNING]
> - **Writing a principal rule without STRICT mTLS.** Plain-text callers have no principal, so they are denied by the rule, or they bypass your intent if another policy allows them.
> - **Writing the principal with the `spiffe://` prefix.** The `principals` field uses the form `cluster.local/ns/<namespace>/sa/<serviceaccount>`.
> - **Forgetting that the first ALLOW policy changes the default to deny.** Add a rule for every legitimate caller, including health checks and monitoring.
> - **Putting every client on the default ServiceAccount.** All of them then share one identity, so the policy cannot tell them apart.
> - **Assuming the policy protects Pods without a sidecar.** It is enforced in the sidecar.
