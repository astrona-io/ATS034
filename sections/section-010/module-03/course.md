---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Roll Out Pod Security Labels Across Namespaces

A cluster has many namespaces and many teams. Labelling one namespace is a command. Labelling all of them without breaking a running application is a plan: find what would fail, warn the owners, fix the workloads, and only then enforce. The Pod Security Admission configuration of the cluster, which sets the defaults and the exemptions, decides what happens to every namespace that has no label of its own. This module covers the plan, the staged change, the cluster configuration and the long-term upkeep.

The module has four parts. **Inventory Before You Label** shows how to list the labels of every namespace and how to ask the API server what a label would break. **Stage A Label Change** applies `warn`, `audit` and `enforce` in order to a namespace that already runs a Deployment, and ends with a graded task. **Cluster-Wide Defaults And Exemptions** explains the admission configuration file that the API server reads. **Exceptions, Upgrades And Ongoing Checks** covers namespaces that must stay Privileged, version pins across cluster upgrades and who may change the labels.

## Learning objectives

After this module you can:

- List the Pod Security labels of all namespaces and find the workloads that a stricter label would block.
- Apply `warn` and `audit` first, fix the workloads, and then apply `enforce` with a pinned version.
- Explain what the cluster-wide defaults and the exemptions do and where they are configured.
- Keep a namespace for workloads that need node access without weakening the other namespaces.
- Explain how a version pin behaves in a cluster upgrade and which permission lets a user change the labels.

## Before you start

You need Pods, Deployments, namespaces and labels, and you should know that Pod Security Admission checks a Pod against a profile selected by namespace labels in the modes `enforce`, `audit` and `warn`. The earlier modules of this section explain the profiles and the Pod fields. This module repeats the facts it needs.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. These namespaces and workloads exist when it starts:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas), the `probe` Service on port 80, and `shuttle`, a `busybox` client pod. The Pods run as root |
| `outpost` | `drifter`, a `busybox` client pod that runs as root |

Neither namespace has Pod Security labels. `kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
