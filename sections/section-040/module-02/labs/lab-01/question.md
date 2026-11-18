---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Override Mesh-Wide STRICT For One Namespace

Allow about 10 minutes for the tasks.

The mesh requires mutual TLS everywhere. For one more quarter, the `drifter` in `outpost-034-040-02-01` must still reach the `probe` in `starfleet-034-040-02-01` with plain text, while the `cargo` in `depot-034-040-02-01` stays locked down.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`, together with the mesh-wide PeerAuthentication `default` (mode `STRICT`, no selector). The namespace `starfleet-034-040-02-01` runs the Deployment `probe`, the Service `probe` on port 80 and the client pod `shuttle`. The namespace `depot-034-040-02-01` runs the Deployment `cargo` and the Service `cargo` on port 80. Both namespaces have the label `istio-injection=enabled`, so these pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-01` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. Right now the `drifter` pod is refused by both `probe` and `cargo`.

## Tasks

1. In `starfleet-034-040-02-01`, create a PeerAuthentication named `namespace-permissive` that covers the whole namespace and sets the mode `PERMISSIVE`.
2. Keep the mesh-wide policy `default` in `istio-system` exactly as it is.
3. Do not create any policy in `depot-034-040-02-01`. The `cargo` Service there must keep refusing plain text.

## Check your work

Wait a few seconds after you apply the policy, then send three requests:

```sh
kubectl -n outpost-034-040-02-01 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01.svc.cluster.local/
kubectl -n starfleet-034-040-02-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-01.svc.cluster.local/
kubectl -n outpost-034-040-02-01 exec drifter -c client -- wget -q -T 3 -O- http://cargo.depot-034-040-02-01.svc.cluster.local/
```

The first two commands must print a line that starts with `version=v1`. The third must fail with `Connection reset by peer`.
