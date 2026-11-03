---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Node And Workload Separation For Tenants

A sandbox changes the boundary of one Pod. Some tenants need more: their Pods must never share a node with other tenants, and nothing a tenant does may move another tenant's Pod next to theirs. This is node-level separation. It also covers the shared resources that a node boundary does not fix, such as host paths, storage and daemons that run on every node.

This module builds a dedicated node for one tenant with labels, taints and tolerations, shows why those labels must be protected from the nodes themselves, forces placement at admission so tenants cannot skip it, and finishes with a way to choose between namespaces, sandboxes, dedicated nodes and separate clusters.

The module has four parts. **Dedicated Nodes With Taints And Tolerations** reserves a node for one tenant, and ends with a graded task. **Node Labels You Can Trust** explains the NodeRestriction admission plugin. **Forcing Placement At Admission** makes the placement mandatory. **Choosing A Tenant Boundary** compares the options with worked cases.

## Learning objectives

After this module you can:

- Reserve a node for one tenant with a label, a taint and a toleration, and explain what each one does.
- Tell `NoSchedule`, `PreferNoSchedule` and `NoExecute` apart.
- Explain why isolation labels need the `node-restriction.kubernetes.io/` prefix.
- Check which admission plugins force node selectors and tolerations.
- Choose between namespaces, sandboxed runtimes, dedicated nodes and separate clusters for a given threat.

## Before you start

You need Pods, Deployments, namespaces, labels and the commands `kubectl get`, `kubectl apply`, `kubectl label` and `kubectl describe`. You do not need an earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. The control-plane node already carries a taint that keeps ordinary Pods away. The namespace `tenant-c` exists and is empty. `kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
