---
exam_objectives:
- Use appropriate pod security standards
---
# Roll Out Restricted Using A Dry-Run Inventory

Allow about 10 minutes for the tasks.

Three teams share the cluster. The security team wants the Restricted profile everywhere, but only where it does not break a running workload today.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Three namespaces have no Pod Security labels:

- `bridge-034-010-03-01` runs the Deployment `bridge`.
- `starfleet-034-010-03-01` runs the Deployment `shuttle`.
- `outpost-034-010-03-01` runs the Pod `drifter`.

All three run `docker.io/library/busybox:1.37.0` with the command `sleep infinity`. You do not know yet which of them meet the Restricted profile.

## Tasks

1. Find out, without changing anything, which namespaces run only Pods that meet the Restricted profile at version `v1.35`.
2. In every namespace where all running Pods comply, enforce `restricted` pinned to `v1.35`.
3. In every other namespace, do not enforce Restricted. Set the `warn` mode to `restricted` pinned to `v1.35`, so that new Pods are still admitted but the team sees a warning.
4. Do not change, delete or restart any workload.

## Check your work

```sh
kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn | grep 034-010-03-01
kubectl get pods -A | grep 034-010-03-01
```

Only the namespace whose Pods comply shows `restricted` in the enforce column. The two others show `restricted` in the warn column, and all three workloads are still `Running`.
