---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Client TLS Setting That Breaks STRICT Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Two different Istio objects control mutual TLS. A PeerAuthentication controls the server side: what the receiving sidecar accepts. A DestinationRule controls the client side: its `trafficPolicy.tls.mode` field tells the sending sidecar how to connect to a host. `ISTIO_MUTUAL` means mutual TLS with Istio certificates, and `DISABLE` means plain text. When no DestinationRule sets a TLS mode, the sending sidecar uses mutual TLS on its own whenever the receiving pod has a sidecar.

Start with the server side. Save this as `peerauthentication-namespace-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet-034-040-02-03
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

Then send the request from the `shuttle` pod again. Leave out `-q` so that `wget` prints the HTTP status:

```sh
kubectl -n starfleet-034-040-02-03 exec shuttle -c client -- wget -T 3 -O- http://probe.starfleet-034-040-02-03.svc.cluster.local/
```

The request now fails with `HTTP/1.1 503 Service Unavailable`. The 503 comes from the shuttle sidecar: it could not open a working connection to the probe sidecar. A failure from a client that has a sidecar points to the client side, so list the DestinationRules:

```sh
kubectl get destinationrules -A
kubectl -n starfleet-034-040-02-03 get destinationrule probe-disable-tls -o yaml
```

The rule `probe-disable-tls` sets `tls.mode: DISABLE` for the host `probe.starfleet-034-040-02-03.svc.cluster.local`. The shuttle sidecar follows it and sends plain text, and the probe sidecar, now STRICT, resets that connection. Remove the rule, so that the sidecar goes back to mutual TLS on its own:

```sh
kubectl -n starfleet-034-040-02-03 delete destinationrule probe-disable-tls
```

Setting `tls.mode: ISTIO_MUTUAL` in the rule is also correct. Then check the result:

```sh
kubectl -n starfleet-034-040-02-03 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-03.svc.cluster.local/
kubectl -n outpost-034-040-02-03 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-03.svc.cluster.local/
```

The `shuttle` request prints a line that starts with `version=v1`. Because the probe sidecar accepts only mutual TLS, a working request from `shuttle` shows that its sidecar now uses mutual TLS. The `drifter` request still fails with `wget: error getting response: Connection reset by peer`.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-02-03`.

## Common pitfalls

> [!WARNING]
> Do not fix a 503 under STRICT by going back to PERMISSIVE. That hides the client setting and lets plain text in again. Find the DestinationRule that sets the client TLS mode.
>
> A DestinationRule can sit in another namespace and still match the host. Search all namespaces with `kubectl get destinationrules -A`, not only the namespace of the Service.
