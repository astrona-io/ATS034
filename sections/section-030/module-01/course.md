---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Tenant Isolation And Sandboxed Containers

A cluster that runs workloads for more than one team, customer or trust level is a multi-tenant cluster. Kubernetes gives each tenant a namespace, but a namespace is a name scope, not a wall. Pods of different namespaces share nodes, share one Linux kernel per node, and can reach each other over the network unless something prevents it. Isolation is the work of adding that something, one layer at a time.

This module builds the layers for one tenant: access control, admission, a resource budget, network rules and a limited identity inside the Pod. It then covers the layer that namespaces cannot give, a separate kernel boundary for untrusted code, through sandboxed container runtimes and `RuntimeClass`.

The module has four parts. **Namespaces And RBAC As A Tenant Boundary** defines the tenant model and sets up a namespace that one user can manage. **Resource Isolation With ResourceQuota And LimitRange** limits what a tenant can consume. **Network Isolation And Token Minimization** blocks traffic with a default-deny `NetworkPolicy` and removes the ServiceAccount token from Pods that do not need it, and ends with a graded task. **Sandboxed Containers With RuntimeClass** explains gVisor and Kata Containers and how a Pod selects them.

## Learning objectives

After this module you can:

- Explain what a namespace isolates and what it does not, and state the difference between soft and hard multi-tenancy.
- Give a user access to one namespace only with a Role and a RoleBinding, and verify it with `kubectl auth can-i`.
- Limit a tenant with a `ResourceQuota` and give containers defaults with a `LimitRange`.
- Block all traffic of a namespace with a default-deny `NetworkPolicy` and allow one path through it.
- Stop a Pod from receiving a ServiceAccount token it does not use.
- Select a sandboxed runtime for a Pod with a `RuntimeClass` and say what it protects against.

## Before you start

You need Kubernetes basics: Pods, namespaces, Deployments, Services, labels and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. It uses the Calico network plugin, which enforces `NetworkPolicy`. It has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas, port 8080), the `probe` Service on port 80, and `shuttle`, a `busybox` client pod |
| `outpost` | `drifter`, a `busybox` client pod |

`kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
