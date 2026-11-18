---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS With PeerAuthentication Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A PeerAuthentication is an Istio object that tells the sidecar proxies which incoming traffic they accept. Its `mtls.mode` field takes `PERMISSIVE` (accept mutual TLS and plain text), `STRICT` (accept only mutual TLS) or `DISABLE` (accept only plain text). A policy without a `selector` covers every workload in its namespace. `istiod`, the Istio control plane, turns the policy into listener configuration and sends it to each sidecar.

In this lab one namespace-wide policy is enough. The `shuttle` pod keeps working because its sidecar opens a mutual TLS connection to the probe sidecar on its own. The `drifter` pod has no sidecar, so it sends plain HTTP, and the probe sidecar now resets that connection.

Save this as `peerauthentication-namespace-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet-034-040-01-01
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

Then check the result. Wait a few seconds so that `istiod` can push the change, and send one request from each client:

```sh
kubectl -n starfleet-034-040-01-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-01.svc.cluster.local/
kubectl -n outpost-034-040-01-01 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-01.svc.cluster.local/
```

The `shuttle` request prints a line that starts with `version=v1`. The `drifter` request fails with `wget: error getting response: Connection reset by peer`. The reset comes from the probe sidecar: it waits for a TLS handshake and closes the connection when plain HTTP arrives.

A mesh-wide policy in `istio-system` with the same `spec` also passes, because Istio uses the mesh-wide policy for every namespace that has no policy of its own. The namespace policy is the safer answer here: it changes only the namespace the task names.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-01-01`.

## Common pitfalls

> [!WARNING]
> A policy with `mode: STRICT` proves nothing on its own. Always send one request that must work and one that must fail, from a client with a sidecar and from a client without one.
>
> Do not test only from a pod with a sidecar. Its sidecar uses mutual TLS anyway, so the request works with or without the policy.
