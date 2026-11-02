---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS Between Workloads Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-01" || exit 1
node_name="astro-ats-034-lab-040-01-01-control-plane"
worker_name="astro-ats-034-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Apply namespace-strict PeerAuthentication with STRICT mutual TLS to starfleet. Keep Istio 1.30.5 running and the application and shuttle Pods injected and Ready. Shuttle with its proxy must receive version one, while the unmeshed outpost drifter must fail its plaintext request with a connection-reset response. This verifies one service-mesh boundary, not host traffic or encryption for every possible path.

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

Apply the scoped correction:

```sh
kubectl apply -f peerauthentication-namespace-strict.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet exec shuttle -c client -- wget -q -T 3 -O- http://probe/
kubectl -n outpost exec drifter -- wget -q -T 3 -O- http://probe.starfleet/
```

Require mesh-authenticated traffic while keeping the injected client able to reach the application. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-040-01-01`.

## Common pitfalls

> [!WARNING]
> Enabling namespace injection does not change existing Pods. Recreate them and verify actual proxies. A declaration of STRICT is not evidence of encryption unless the allowed and denied traffic paths are tested.
