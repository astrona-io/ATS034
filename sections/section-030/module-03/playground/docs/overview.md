---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Node Separation Playground

This playground is a private `kind` cluster for the node separation module. `kind` (Kubernetes in Docker) runs each Kubernetes node as a container on your computer. The cluster runs Kubernetes 1.35 with one control-plane node, `astro-ats-034-playground-030-03-control-plane`, and one worker node, `astro-ats-034-playground-030-03-worker`.

## Connect to the cluster

A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. Point kubectl at the playground and check the context before you change anything:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-030-03" || exit 1
```

The `test` command stops the shell when the context is wrong. Keep this connection for every command of the module.

## What the playground contains

The namespace `tenant-c` exists and is empty. The worker node has no `tenant` label and no `tenant` taint. The control-plane node carries the taint `node-role.kubernetes.io/control-plane:NoSchedule`, which keeps ordinary Pods away from it. Read both nodes with their taints:

```sh
kubectl get nodes --show-labels
kubectl describe nodes | grep -A 1 Taints
```

The pages of the module label and taint the worker, run Pods in `tenant-c` and add a ValidatingAdmissionPolicy. To remove a label, run `kubectl label node <node> tenant-`. To remove a taint, run `kubectl taint node <node> tenant=tenant-c:NoSchedule-`. To start from the beginning, stop the playground and launch it again.

## Common pitfalls

> [!WARNING]
> Check the context before every change. A label or taint on a node of another cluster changes where that cluster runs its Pods.
>
> A ValidatingAdmissionPolicy stays in the cluster after the page ends. Delete it and its binding with `kubectl delete validatingadmissionpolicybinding require-tenant-node-tenant-c` and `kubectl delete validatingadmissionpolicy require-tenant-node` before you run Pods without the selector in `tenant-c`.
