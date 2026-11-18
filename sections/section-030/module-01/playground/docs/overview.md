---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Tenant Isolation Playground

This playground is a private `kind` cluster for the tenant isolation module. `kind` (Kubernetes in Docker) runs each Kubernetes node as a container on your computer. The cluster runs Kubernetes 1.35 with one control-plane node and one worker node. It uses the Calico network plugin, which enforces `NetworkPolicy`.

## Connect to the cluster

A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. Point kubectl at the playground and check the context before you change anything:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-030-01" || exit 1
```

The `test` command stops the shell when the context is wrong. Keep this connection for every command of the module.

## What the playground contains

The namespace `starfleet` holds the `probe` Deployment with two replicas that answer HTTP requests on port 8080, the `probe` Service on port 80, and the `shuttle` Pod, a `busybox` client. The namespace `outpost` holds the `drifter` Pod, a second `busybox` client. No NetworkPolicy, ResourceQuota or LimitRange exists yet, so every Pod can reach every other Pod. List the objects:

```sh
kubectl -n starfleet get deployments,services,pods -o wide
kubectl -n outpost get pods -o wide
kubectl get nodes
```

The pages of the module create their own namespaces (`tenant-demo`, `quota-demo` and `network-demo`) next to these objects. You can delete any of them and apply the page YAML again. To start from the beginning, stop the playground and launch it again.

## Common pitfalls

> [!WARNING]
> Check the context before every change. A command against another cluster changes that cluster, not the playground.
>
> The playground has no gVisor or Kata Containers handler. A Pod that asks for one is accepted but never starts.
