---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To Strict mTLS With One Exception Solution

The task has two policies. The namespace policy sets `STRICT` for every workload. The workload policy replaces it for the Pods labelled `app: legacy`, because the narrower scope wins.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-01" || exit 1
```

## Inspect the starting state

Check that every Pod has a sidecar, and that both clients reach both workloads before you change anything:

```sh
kubectl -n starfleet-034-040-02-01 get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
kubectl -n outpost-034-040-02-01 exec drifter -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01/
kubectl -n outpost-034-040-02-01 exec drifter -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-01/
```

Each Pod in `starfleet-034-040-02-01` lists an `istio-proxy` container, and both requests return a line that starts with `version=`.

## Require STRICT for the namespace

Save this as `peerauthentication-namespace-strict.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: starfleet-034-040-02-01
spec:
  mtls:
    mode: STRICT
```

Apply it:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

## Add the exception for legacy

Save this as `peerauthentication-legacy-permissive.yaml`:

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: legacy-permissive
  namespace: starfleet-034-040-02-01
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

## Verify the result

Run the four requests. The denied one returns a nonzero status, so run it on its own:

```sh
kubectl -n starfleet-034-040-02-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe/
kubectl -n starfleet-034-040-02-01 exec shuttle -c client -- wget -q -T 3 -O- http://legacy/
kubectl -n outpost-034-040-02-01 exec drifter -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-01/
kubectl -n outpost-034-040-02-01 exec drifter -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01/
```

The first three return a `version=` line. The fourth fails with a connection reset because the sidecar of `probe` requires mTLS and `drifter` sends plain text. If the fourth request still works, wait a few seconds and repeat it.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> - **A selector label that the Pods do not have.** The exception then selects nothing and `legacy` stays strict.
> - **Putting the exception on the namespace.** A `PERMISSIVE` namespace policy opens `probe` to plain text as well.
> - **Testing only the allowed paths.** The `probe` denial is half of the result.
> - **Deleting the namespace policy to fix the legacy path.** The task needs both policies.
