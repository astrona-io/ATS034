---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Choosing A Tenant Boundary

Every isolation layer costs money, effort or both. A cluster that gives each tenant a separate cluster wastes capacity on trusted teams. A cluster that relies on namespaces alone fails against hostile code. This part states what each boundary stops, then works through cases and shared resources that a node boundary does not fix.

## What each boundary stops

A namespace with RBAC, quota, network policy and a restricted security context stops accidental interference and most API abuse. It does not stop a kernel exploit, because the kernel is shared. A sandboxed runtime adds a second kernel boundary for one Pod, but Pods of different tenants can still share a node, its disk and its daemons. A dedicated node group keeps tenants on different machines. A separate cluster also separates the control plane, the API server credentials and cluster-scoped objects.

| Boundary | Stops | Does not stop |
| --- | --- | --- |
| Namespace and policy | Name clashes, API access, noisy neighbours, open network paths | Kernel exploits, node-level attacks |
| Sandboxed runtime | Kernel exploits from container code | Shared node resources, other layers |
| Dedicated nodes | Cross-tenant node access | Control-plane and cluster-scoped sharing |
| Separate cluster | Shared control plane | Shared cloud account and network |

## Shared resources that cross a node boundary

Several resources reach across tenants even on dedicated nodes. A `hostPath` volume gives a Pod a directory of the node, so it can read other containers' data on a shared node. Restricted Pod Security forbids `hostPath`, but only if the namespace enforces it. A DaemonSet runs a Pod on every node, including dedicated ones, and it often holds broad rights. A shared storage class lets one tenant's claim land on a volume pool used by others. The cluster DNS and the API server are shared by definition.

Check what runs on the dedicated node. This lists every Pod on it, across all namespaces:

<!-- astrona:playground:renew -->

```sh
kubectl get pods --all-namespaces --field-selector spec.nodeName=astro-ats-034-playground-030-03-worker
```

The list shows the system Pods that run on every node, such as the network plugin agent. Those Pods are not tenant workloads, but they share the node, and a compromise of the node reaches them. Include them in the threat model.

## Worked decisions

Case one: three internal teams that trust each other and want separate budgets. Namespaces with quota and default-deny network policy are enough, and cost stays low. Case two: a platform that runs code uploaded by customers. The code is hostile, so add a sandboxed runtime, a dedicated node group per customer class, and a policy that requires the class. Case three: a regulated tenant with its own audit scope. A separate cluster fits, because the tenant needs its own control plane, credentials and audit log.

Failure cases follow the same pattern. A team picks a sandbox and skips the network policy: the sandboxed Pod still reaches every Service. A team adds a taint and skips the selector: its Pods run on shared nodes. A team uses a custom label and skips NodeRestriction: a compromised node attracts the tenant. Each failure comes from treating one layer as the whole boundary.

You now have the full set of tools: namespaces and policy, sandbox runtimes, dedicated nodes and enforcement at admission. The choice depends on how hostile the code is and what a breach costs. State the threat first, then pick the cheapest set of layers that covers it.

## Common pitfalls

> [!WARNING]
> - **Choosing the strongest boundary for every tenant.** Cost and effort rise, and unneeded layers add faults.
> - **Choosing namespaces for hostile code.** The kernel stays shared.
> - **Ignoring DaemonSets and host paths.** They reach across the node boundary.
> - **Forgetting the shared control plane.** Only a separate cluster separates it.
