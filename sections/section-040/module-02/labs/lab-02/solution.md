---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To STRICT With One Exception Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A safe migration to STRICT has two steps. First, a namespace-wide policy sets `STRICT` for every workload. Second, a workload policy with a `selector` gives the one workload that still has a plain-text client a `PERMISSIVE` exception. Istio picks the most specific policy for each pod, so the `legacy` pods use the workload policy and every other pod uses the namespace policy.

Save this as `peerauthentication-namespace-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet-034-040-02-02
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

Now the `drifter` pod is refused by both Services. The exception gives the `legacy` pods their plain-text access back.

Save this as `peerauthentication-legacy-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: legacy-permissive
  namespace: starfleet-034-040-02-02
spec:
  selector:
    matchLabels:
      app: legacy
  mtls:
    mode: PERMISSIVE
```

Apply it:

```sh
kubectl apply -f peerauthentication-legacy-permissive.yaml
```

Then check the result. Wait a few seconds so that `istiod` can push the change:

```sh
kubectl -n starfleet-034-040-02-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n starfleet-034-040-02-02 exec shuttle -c client -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n outpost-034-040-02-02 exec drifter -c client -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n outpost-034-040-02-02 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-02.svc.cluster.local/
```

The first three requests print a line that starts with `version=`. The last fails with `wget: error getting response: Connection reset by peer`, because the probe sidecar still follows the namespace `STRICT` policy.

A port-level exception is a narrower answer that also passes. Instead of `mtls.mode: PERMISSIVE`, the `legacy-permissive` policy can keep the workload STRICT and open only one port with `portLevelMtls`. The port number is the container port (8080), not the Service port (80):

```yaml
spec:
  selector:
    matchLabels:
      app: legacy
  portLevelMtls:
    8080:
      mode: PERMISSIVE
```

When you are done, remove the lab with `astrona destroy ats-034-lab-040-02-02`.

## Common pitfalls

> [!WARNING]
> `portLevelMtls` uses the container port that the sidecar receives, not the Service port. A setting for port 80 does nothing here, because the legacy container listens on 8080.
>
> Check the exception selector against the pod labels. A selector that also matches the probe pods quietly removes STRICT from them.
