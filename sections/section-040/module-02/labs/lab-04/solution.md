---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Wrong Principal In An AuthorizationPolicy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

An AuthorizationPolicy is an Istio resource that tells the sidecar proxy (Envoy) of the selected pods which requests to accept. With the action `ALLOW`, the receiving sidecar accepts a request only when it matches a rule, and it answers every other request with HTTP 403. A rule can match the caller by its principal. The principal is the workload identity from the certificate of the calling sidecar: its SPIFFE ID without the `spiffe://` prefix. A SPIFFE ID is a URI of the form `spiffe://<trust-domain>/ns/<namespace>/sa/<serviceaccount>`, and `istiod` writes it into the certificate when it signs the certificate for the pod's ServiceAccount.

Start with the symptom. Send a request from the `shuttle` pod and leave out `-q`, so that `wget` prints the HTTP status:

```sh
kubectl -n starfleet-034-040-02-04 exec shuttle -c client -- wget -T 3 -O- http://probe.starfleet-034-040-02-04.svc.cluster.local/
```

The request fails:

```text
Connecting to probe.starfleet-034-040-02-04.svc.cluster.local (10.96.231.156:80)
wget: server returned error: HTTP/1.1 403 Forbidden
command terminated with exit code 1
```

The IP address of the Service is different in your cluster. A 403 means that the connection worked and the probe sidecar refused the request on purpose. So the mutual TLS (mTLS) connection is fine, and the problem is in the AuthorizationPolicy. Look at the policy:

```sh
kubectl -n starfleet-034-040-02-04 get authorizationpolicy probe-allow-shuttle -o yaml
```

The rule admits one principal, and that principal names the ServiceAccount `probe-client`:

```yaml
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet-034-040-02-04/sa/probe-client
  selector:
    matchLabels:
      app: probe
```

The output above is shortened to the `spec` part. Do not guess what the `shuttle` presents instead. Ask its sidecar for its certificates. `pilot-agent` is the process in the `istio-proxy` container that gets the certificate from `istiod`, and it can print what Envoy holds. The full answer is long JSON with the same entry many times, so filter it for the SPIFFE ID:

```sh
kubectl -n starfleet-034-040-02-04 exec shuttle -c istio-proxy -- pilot-agent request GET certs | grep -m1 spiffe
```

The output shows the identity in the `subject_alt_names` entry of the certificate:

```text
2026/11/21 08:54:04 INFO GOMEMLIMIT is already set, skipping package=github.com/KimMachineGun/automemlimit/memlimit GOMEMLIMIT=1073741824
       "uri": "spiffe://cluster.local/ns/starfleet-034-040-02-04/sa/shuttle"
```

The first line is a log line from `pilot-agent` itself and does not matter here. The SPIFFE ID ends in `sa/shuttle`, so the `shuttle` pod runs as the ServiceAccount `shuttle`, and no ServiceAccount `probe-client` is involved. You can confirm the ServiceAccount from the pod spec:

```sh
kubectl -n starfleet-034-040-02-04 get pod shuttle -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

It prints `shuttle`. Write the principal as the SPIFFE ID without `spiffe://`. Save this as `authorizationpolicy-probe-allow-shuttle.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-shuttle
  namespace: starfleet-034-040-02-04
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet-034-040-02-04/sa/shuttle
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-allow-shuttle.yaml
```

`istiod` sends the new rule to the probe sidecar. In this lab that took between 10 and 25 seconds, so send the requests again until the result changes. Then check the result:

```sh
kubectl -n starfleet-034-040-02-04 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-04.svc.cluster.local/
kubectl -n starfleet-034-040-02-04 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-04.svc.cluster.local/
```

The `shuttle` request prints `version=v1 host=probe-54f5f879c6-8rxcm`; the pod name is different in your cluster. The `drifter` request still fails with `wget: server returned error: HTTP/1.1 403 Forbidden`. The `drifter` pod has a sidecar and a valid certificate too, but its SPIFFE ID ends in `sa/default`, because the pod runs as the ServiceAccount `default`. That principal is not in the rule, so the probe sidecar refuses it.

A rule with `namespaces: [starfleet-034-040-02-04]` would also admit the `shuttle`, but it admits every pod of the namespace, the `drifter` included. In this lab, that change made the `drifter` request print `version=v1`. A wildcard principal such as `*` has the same effect. Only the exact principal keeps the `drifter` out.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-02-04`.

## Common pitfalls

> [!WARNING]
> Do not copy the `spiffe://` prefix into the policy. The `principals` field takes the SPIFFE ID without it, for example `cluster.local/ns/starfleet-034-040-02-04/sa/shuttle`.
>
> A 403 from a meshed client means the sidecar refused the request by policy. A connection reset or a 503 points to a TLS problem instead. Read the status before you change mTLS settings.
>
> The principal names a ServiceAccount, not a pod or a Deployment. Two pods with the same ServiceAccount have the same identity, and a rule cannot tell them apart.
