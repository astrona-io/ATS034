---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS With PeerAuthentication

Allow about 10 minutes for the tasks.

The `probe` Service in `starfleet-034-040-01-01` must stop accepting plain text. The `drifter` in `outpost-034-040-01-01` has no sidecar and must lose access; the `shuttle` next to the probe must keep working.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-01-01` has the label `istio-injection=enabled` and runs the Deployment `probe` (one replica, HTTP on container port 8080), the Service `probe` on port 80 and the client pod `shuttle`. Each of these pods has an `istio-proxy` sidecar. The namespace `outpost-034-040-01-01` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists, so the probe sidecar accepts both mutual TLS and plain text.

## Tasks

1. Require STRICT mutual TLS (mTLS) for every workload in `starfleet-034-040-01-01`. A namespace-wide PeerAuthentication in `starfleet-034-040-01-01` or a mesh-wide one in `istio-system` both count.
2. Do not remove or change the workloads, and keep their sidecars.
3. The `shuttle` pod must still get a reply from the `probe` Service, and the `drifter` pod must be refused.

## Check your work

Wait a few seconds after you apply a policy: `istiod` must first send the new configuration to the sidecars. Then send one request from each client:

```sh
kubectl -n starfleet-034-040-01-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-01.svc.cluster.local/
kubectl -n outpost-034-040-01-01 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-01.svc.cluster.local/
```

The first command must print a line that starts with `version=v1`. The second must fail with `Connection reset by peer`.
