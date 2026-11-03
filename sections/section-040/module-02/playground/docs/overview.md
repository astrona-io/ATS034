---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Guided Practice: Migrate A Namespace To Strict mTLS

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-040-02" || exit 1
```

Keep this connection selected.

## Inspect the starting state

The `starfleet` namespace has the `probe` and `legacy` workloads and the client `shuttle`, all with sidecars. The client `drifter` in `outpost` has no sidecar. No `PeerAuthentication` exists.

```sh
kubectl -n starfleet get pods -o wide
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://legacy.starfleet/
```

## Apply the policies

Save this as `peerauthentication-namespace-strict.yaml`:

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

Save this as `peerauthentication-legacy-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: legacy-permissive
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: legacy
  mtls:
    mode: PERMISSIVE
```

Apply both:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml -f peerauthentication-legacy-permissive.yaml
```

## Verify the result

Run the allowed requests, then the denied request on its own:

```sh
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe/
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://legacy/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://legacy.starfleet/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet/
```

The first three return a `version=` line. The last one fails with a connection reset.

## Common pitfalls

> [!WARNING]
> A declared policy is not evidence of encryption. Test the allowed and the denied path. Pods created before injection need a restart to get a sidecar.
