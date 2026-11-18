---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Dedicate A Node To One Tenant With Taints And Tolerations

Allow about 10 minutes for the tasks.

Tenant C must run on its own worker node, and no other namespace may place Pods there. The `drifter` in `outpost` will try.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The cluster has two nodes: `astro-ats-034-lab-030-03-01-control-plane` and `astro-ats-034-lab-030-03-01-worker`. The namespaces `tenant-c-034-030-03-01` and `outpost-034-030-03-01` are empty. The worker node has no `tenant` label and no `tenant` taint.

## Tasks

1. Label the worker node `tenant=tenant-c`.
2. Taint the worker node `tenant=tenant-c:NoSchedule`. Do not label or taint the control-plane node.
3. In `tenant-c-034-030-03-01`, create the Deployment `tenant-c-app` with one replica, the label `app: tenant-c-app`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep infinity"`. Its Pod template sets the node selector `tenant: tenant-c` and tolerates the taint with the `Equal` operator.
4. In `outpost-034-030-03-01`, create the Pod `drifter` with the node selector `tenant: tenant-c`, no toleration, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep infinity"`. It must stay `Pending`.

## Check your work

```sh
kubectl -n tenant-c-034-030-03-01 get pods -o wide
kubectl -n outpost-034-030-03-01 get pod drifter
```

The `tenant-c-app` Pod must run on the worker node. The `drifter` Pod must show `Pending`, and the `FailedScheduling` event in `kubectl describe` must report untolerated taints.
