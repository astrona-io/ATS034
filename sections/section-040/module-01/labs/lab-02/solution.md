---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Allow One Workload Identity With AuthorizationPolicy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

An AuthorizationPolicy is an Istio object that tells the sidecar proxy of the selected pods which requests it lets through. With `action: ALLOW`, the sidecar lets a request through only when it matches one of the rules; every other request gets HTTP 403. A rule's `from.source.principals` field matches the workload identity of the caller. Istio writes that identity into the caller's mutual TLS certificate in the form `cluster.local/ns/<namespace>/sa/<service-account>`.

Both clients have a sidecar, so both connect with mutual TLS and both present a certificate. The probe sidecar reads the principal from the certificate and compares it with the rule. The `shuttle` pod runs as the ServiceAccount `shuttle`, so its principal is `cluster.local/ns/starfleet-034-040-01-02/sa/shuttle`.

Save this as `authorizationpolicy-probe-allow-shuttle.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-shuttle
  namespace: starfleet-034-040-01-02
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet-034-040-01-02/sa/shuttle
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-allow-shuttle.yaml
```

Then check the result. Wait a few seconds so that `istiod` can push the policy to the probe sidecar:

```sh
kubectl -n starfleet-034-040-01-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-02.svc.cluster.local/
kubectl -n starfleet-034-040-01-02 exec tender -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-02.svc.cluster.local/
```

The `shuttle` request prints a line that starts with `version=v1`. The `tender` request fails with `wget: server returned error: HTTP/1.1 403 Forbidden`. The probe application never returns 403, so this answer comes from the probe sidecar: the `tender` principal matches no rule of the ALLOW policy.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-01-02`.

## Common pitfalls

> [!WARNING]
> A principal is built from the ServiceAccount, not from the pod name or a pod label. Check the ServiceAccount with `kubectl get pod <name> -o jsonpath='{.spec.serviceAccountName}'` before you write the rule.
>
> An ALLOW policy with an empty `rules` list matches nothing, so it denies every request, including the one you wanted to allow.
