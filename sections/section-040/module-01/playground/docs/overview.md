---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Guided Practice: Require Mutual TLS Between Workloads

This playground is a kind cluster with two nodes and Istio 1.30.5. The namespace `starfleet` has the label `istio-injection=enabled`, so its pods run the Envoy sidecar proxy, an extra container that handles all traffic of the pod. It runs the `probe` Deployment (two replicas), the `probe` Service on port 80 and the client pod `shuttle`. The namespace `outpost` runs the client pod `drifter`, which has no sidecar.

Connect a host shell to the playground first. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-040-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-040-01" || exit 1
```

## Look at the starting state

Check that the sidecars exist and that both clients reach the `probe` Service:

```sh
kubectl -n starfleet get pods -o wide
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe/
kubectl -n outpost exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet/
```

Both requests return a line that starts with `version=v1`. No `PeerAuthentication` exists yet, so the `probe` sidecars run in permissive mode and accept plain text from `drifter` as well as mTLS (mutual Transport Layer Security) from the `shuttle` sidecar.

## Require mTLS for the namespace

A `PeerAuthentication` tells the sidecars which incoming traffic they accept. Save this as `peerauthentication-namespace-strict.yaml`:

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

Then send the two requests again. Run the second one on its own, because it fails when the policy works:

```sh
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe/
kubectl -n outpost exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet/
```

The `shuttle` request still returns `version=v1`, because its sidecar sends mTLS. The `drifter` request fails with `wget: error getting response: Connection reset by peer`: the `probe` sidecar closes a connection that does not start with a TLS handshake. `istiod` sends the new policy to the sidecars within a few seconds, so if `drifter` still gets a reply, run the request again.

## Common pitfalls

> [!WARNING]
> - **Expecting existing pods to get a sidecar.** The injection label acts only when a pod is created. Restart the pods after you add it.
> - **Treating the policy as proof.** Test the allowed path and the denied path after every change.
