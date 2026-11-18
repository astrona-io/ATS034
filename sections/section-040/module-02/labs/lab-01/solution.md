---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Override Mesh-Wide STRICT For One Namespace Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Istio picks one PeerAuthentication for each workload, and the most specific one wins. A policy with a `selector` that matches the pod comes first. Next comes a policy without a selector in the pod's own namespace. Last comes the mesh-wide policy: a policy without a selector in the root namespace, which is `istio-system` here. So a namespace policy overrides the mesh-wide policy for that namespace only.

In this lab the mesh-wide `default` policy sets `STRICT`. A namespace policy in `starfleet-034-040-02-01` with `PERMISSIVE` makes the probe sidecar accept plain text again, while `depot-034-040-02-01` has no policy of its own and still uses the mesh-wide `STRICT`.

Save this as `peerauthentication-namespace-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-permissive
  namespace: starfleet-034-040-02-01
spec:
  mtls:
    mode: PERMISSIVE
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-permissive.yaml
```

Then check the result. Wait a few seconds so that `istiod` can push the change:

```sh
kubectl -n outpost-034-040-02-01 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01.svc.cluster.local/
kubectl -n starfleet-034-040-02-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01.svc.cluster.local/
kubectl -n outpost-034-040-02-01 exec drifter -c client -- wget -q -T 3 -O- http://cargo.depot-034-040-02-01.svc.cluster.local/
```

The `drifter` and `shuttle` requests to `probe` print a line that starts with `version=v1`. The `shuttle` request still uses mutual TLS, because `PERMISSIVE` accepts both mutual TLS and plain text. The `drifter` request to `cargo` fails with `wget: error getting response: Connection reset by peer`: the cargo sidecar still follows the mesh-wide `STRICT` policy.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> Do not edit or delete the mesh-wide policy to let one client in. That opens every namespace in the mesh. Override it in the one namespace that needs it.
>
> Always test a second namespace after an override. A request that works only proves the override; a request that still fails elsewhere proves its scope.
