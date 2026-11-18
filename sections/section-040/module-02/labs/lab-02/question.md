---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To STRICT With One Exception

Allow about 15 minutes for the tasks.

Everything in `starfleet-034-040-02-02` must stop accepting plain text, except the `legacy` workload: the `drifter` in `outpost-034-040-02-02` cannot get a sidecar this quarter and still calls it.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-02` has the label `istio-injection=enabled` and runs the Deployments `probe` and `legacy` (one replica each, labels `app: probe` and `app: legacy`, HTTP on container port 8080), the Services `probe` and `legacy` on port 80, and the client pod `shuttle`. These pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-02` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists, so every request works.

## Tasks

1. In `starfleet-034-040-02-02`, create a PeerAuthentication named `namespace-strict` that sets `STRICT` for the whole namespace.
2. In `starfleet-034-040-02-02`, create a PeerAuthentication named `legacy-permissive` that selects only the `legacy` pods and lets them accept plain text on their container port 8080. A workload-wide `PERMISSIVE` mode or a port-level setting for port 8080 both count.
3. Keep the workloads and their sidecars as they are.

## Check your work

Wait a few seconds after you apply a policy, then send four requests:

```sh
kubectl -n starfleet-034-040-02-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n starfleet-034-040-02-02 exec shuttle -c client -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n outpost-034-040-02-02 exec drifter -c client -- wget -q -T 3 -O- http://legacy.starfleet-034-040-02-02.svc.cluster.local/
kubectl -n outpost-034-040-02-02 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-02.svc.cluster.local/
```

The first three commands must print a line that starts with `version=`. The last must fail with `Connection reset by peer`.
