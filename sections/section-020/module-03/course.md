---
exam_objectives:
- Manage Kubernetes secrets
---
# Keeping Credentials Out Of Manifests And Images

A credential does not only live in a Secret. It also appears in ConfigMaps, in environment variables written into a manifest, in container images, in Git history and in annotations that tools add without being asked. Each copy is a place to read the credential, and most of them have weaker protection than a Secret. This module follows a credential through those places, shows how external secret stores and encrypted manifests keep it out of the cluster, and ends with the audit log that records who read it.

The module has four parts. **Where Credentials Leak** finds the copies of a credential in a cluster and moves one into a Secret. **External Secret Stores** explains the External Secrets Operator, the Secrets Store CSI driver and how the cluster proves its identity to a store. **Encrypting Secrets For Git** explains Sealed Secrets and SOPS. **Auditing Secret Access** writes an audit policy, turns on the audit log of the kube-apiserver and reads who accessed a Secret. A graded lab follows the first and the last part.

## Learning objectives

After this module you can:

- List the places where a credential is copied in a cluster, and find them with `kubectl`.
- Move a credential from a ConfigMap or an environment variable into a Secret mounted as a file.
- Compare syncing an external secret into a Secret with mounting it directly from the store.
- Explain how Sealed Secrets and SOPS protect a manifest in a Git repository, and what each leaves exposed.
- Choose an audit policy level for Secrets that records access and never records values.

## Before you start

You need Kubernetes basics: Pods, ConfigMaps, namespaces, volumes, and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You should know that a Secret stores values as base64 and that RBAC controls who can read it.

Your playground is a VM (virtual machine) that runs a one-node Kubernetes 1.35 cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods, so you can change the kube-apiserver and read its audit log on the node. The cluster has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `shuttle` client pod, the Secret `practice-token` and the ConfigMap `legacy-settings` that holds the disposable value `disposable-v1` |
| `outpost` | `drifter`, a `busybox` client pod |

Open a shell on the VM with `astrona ssh astro-ats-034-playground-020-03`. You are logged in as the `student` user, and `kubectl` already points at the cluster. Node files and processes belong to root, so run node commands with `sudo`. Every file you save is a file in the home directory of `student` on the VM.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
