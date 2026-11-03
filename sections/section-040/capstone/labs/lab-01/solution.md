---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Encrypt And Authorize Pod Traffic Solution

The task has three results. Two of them depend on each other: an `AuthorizationPolicy` that matches a principal works only when the caller sends an mTLS certificate, which `STRICT` mode guarantees. The third result is a values file and does not depend on the mesh.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-040" || exit 1
```

## Inspect the starting state

Define a helper that sends a request from a client Pod, and confirm that every client reaches `probe`:

```sh
check_probe() { kubectl -n "$1" exec "$2" -- wget -q -T 3 -O- http://probe.starfleet/; }
kubectl get peerauthentication,authorizationpolicy -A
check_probe starfleet shuttle
check_probe starfleet tender
check_probe outpost drifter
```

The first command lists no objects, and the three requests return a line that starts with `version=v1`.

## Require STRICT for the namespace

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

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

## Allow only shuttle

Save this as `authorizationpolicy-probe-allow-shuttle.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: probe-allow-shuttle
  namespace: starfleet
spec:
  selector:
    matchLabels:
      app: probe
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/starfleet/sa/shuttle
```

Apply it:

```sh
kubectl apply -f authorizationpolicy-probe-allow-shuttle.yaml
```

The first `ALLOW` policy for the `probe` Pods turns the default into deny, so every caller that does not match a rule is rejected.

## Set the Cilium values

Save this as `configmap-cilium-values-wireguard.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-values
  namespace: kube-system
data:
  values.json: |
    {
      "encryption": {
        "enabled": true,
        "type": "wireguard",
        "nodeEncryption": true
      }
    }
```

Apply it:

```sh
kubectl apply -f configmap-cilium-values-wireguard.yaml
```

## Verify the result

Send the requests. The denied ones return a nonzero status, so run each on its own:

```sh
check_probe starfleet shuttle
kubectl -n starfleet exec tender -c client -- wget -T 3 -O- http://probe.starfleet/
check_probe outpost drifter
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

The first request returns the `version=v1` line. The second fails with an HTTP 403 error, because the sidecar of `probe` rejects the identity of `tender`. The third fails with a connection reset, because `drifter` sends plain text. The last command shows the three WireGuard settings. If a denied request still works, wait a few seconds and repeat it.

After recording your result, remove the lab with `astrona destroy ats-034-capstone-040`.

## Common pitfalls

> [!WARNING]
> - **Writing the principal with the `spiffe://` prefix.** In an `AuthorizationPolicy` the principal is `cluster.local/ns/starfleet/sa/shuttle`.
> - **Applying the `AuthorizationPolicy` without STRICT mode.** Plain-text callers have no principal, so the rule cannot identify them.
> - **Selecting the wrong Pods.** The selector must match the `app: probe` label.
> - **Testing only the allowed path.** The 403 for `tender` and the reset for `drifter` are part of the result.
> - **Treating the values file as active encryption.** It only prepares the Helm upgrade.
