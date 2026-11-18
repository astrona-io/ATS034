---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Allow One Workload Identity With AuthorizationPolicy

Allow about 10 minutes for the tasks.

Only the `shuttle` may call the `probe` in `starfleet-034-040-01-02`. The `tender` runs next to it with its own sidecar and must be refused.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-01-02` has the label `istio-injection=enabled` and runs the Deployment `probe` (one replica, label `app: probe`, HTTP on container port 8080), the Service `probe` on port 80, and the client pods `shuttle` and `tender`. Each pod runs under a ServiceAccount with its own name (`probe`, `shuttle`, `tender`) and has an `istio-proxy` sidecar. The client pods contain BusyBox `wget`. No AuthorizationPolicy and no PeerAuthentication exist.

## Tasks

1. In `starfleet-034-040-01-02`, create an AuthorizationPolicy named `probe-allow-shuttle` that selects the `probe` pods with the action `ALLOW`.
2. Admit requests only from the workload identity (principal) of the `shuttle` ServiceAccount.
3. Do not change the workloads, their ServiceAccounts or their sidecars.

## Check your work

Wait a few seconds after you apply the policy, then send one request from each client:

```sh
kubectl -n starfleet-034-040-01-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-02.svc.cluster.local/
kubectl -n starfleet-034-040-01-02 exec tender -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-01-02.svc.cluster.local/
```

The first command must print a line that starts with `version=v1`. The second must fail with `403 Forbidden`.
