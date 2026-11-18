---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Client TLS Setting That Breaks STRICT

Allow about 15 minutes for the tasks.

The team turned on STRICT in `starfleet-034-040-02-03` last week and rolled it back an hour later, because the `shuttle` lost access to the `probe`. Turn STRICT on again, and this time keep the `shuttle` working.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-03` has the label `istio-injection=enabled` and runs the Deployment `probe`, the Service `probe` on port 80 and the client pod `shuttle`. These pods have an `istio-proxy` sidecar. The namespace `outpost-034-040-02-03` runs the client pod `drifter` without a sidecar. The client pods contain BusyBox `wget`. No PeerAuthentication exists. Other Istio objects from earlier work may still exist in `starfleet-034-040-02-03`.

## Tasks

1. In `starfleet-034-040-02-03`, create a PeerAuthentication named `namespace-strict` that sets `STRICT` for the whole namespace. Do not weaken it later.
2. Find out why the `shuttle` pod fails once STRICT is on, and fix the cause so that its sidecar uses mutual TLS to the `probe` Service.
3. The `drifter` pod must be refused.

## Check your work

Wait a few seconds after each change, then send one request from each client:

```sh
kubectl -n starfleet-034-040-02-03 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-03.svc.cluster.local/
kubectl -n outpost-034-040-02-03 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-03.svc.cluster.local/
```

The first command must print a line that starts with `version=v1`. The second must fail with `Connection reset by peer`.
