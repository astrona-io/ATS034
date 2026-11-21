---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Wrong Principal In An AuthorizationPolicy

Allow about 10 minutes for the tasks.

The team wrote the policy `probe-allow-shuttle` so that only the `shuttle` may call the `probe` in `starfleet-034-040-02-04`. Since it went live, the `shuttle` gets `403 Forbidden` as well. Find the identity that the `shuttle` really presents and fix the policy, without opening the `probe` to the `drifter`.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Istio 1.30.5 runs in `istio-system`. The namespace `starfleet-034-040-02-04` has the label `istio-injection=enabled` and runs the Deployment `probe` (label `app: probe`), the Service `probe` on port 80 and the client pods `shuttle` and `drifter`. Every pod has an `istio-proxy` sidecar. The `shuttle` pod runs as the ServiceAccount `shuttle`, and the `drifter` pod runs as the ServiceAccount `default`. The client pods contain BusyBox `wget`. The AuthorizationPolicy `probe-allow-shuttle` selects the `probe` pods with the action `ALLOW`.

## Tasks

1. Read the workload identity (the SPIFFE ID) from the certificate of the `shuttle` sidecar.
2. Fix the AuthorizationPolicy `probe-allow-shuttle` so that it admits exactly that identity. Keep its name, its selector and the action `ALLOW`.
3. The `drifter` pod must still get `403 Forbidden`. Do not delete the policy, and do not allow a whole namespace, an IP address range or a wildcard principal.
4. Do not change the workloads, their ServiceAccounts or their sidecars.

## Check your work

`istiod` can take up to about half a minute to send a policy change to the sidecars. Wait, then send one request from each client:

```sh
kubectl -n starfleet-034-040-02-04 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-04.svc.cluster.local/
kubectl -n starfleet-034-040-02-04 exec drifter -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-02-04.svc.cluster.local/
```

The first command must print a line that starts with `version=v1`. The second must fail with `403 Forbidden`.
