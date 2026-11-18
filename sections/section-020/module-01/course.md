---
exam_objectives:
- Manage Kubernetes secrets
---
# Kubernetes Secrets: Storage, Delivery And Rotation

A Secret is the Kubernetes object for small pieces of sensitive data: a password, a token, a TLS key. Many clusters treat Secrets as safe by default, and they are not. The API stores them in `etcd` in an encoding that anyone can reverse, any Pod that mounts one can read it, and a changed value reaches running containers in different ways depending on how the Pod consumes it.

This module explains where a Secret lives, who can read it, how it reaches a container, how to replace its value, and how to encrypt it in `etcd`. Each idea is tested on the playground cluster with a disposable credential, so no real secret ever appears in a command.

The module has four parts. **What A Secret Is And Who Can Read It** shows that the `data` field is base64 encoding, not encryption, and that RBAC decides who reads a Secret. **Delivering Secrets To Pods** compares environment variables with Secret volumes and shows the files the kubelet creates. **Rotating A Secret** replaces a value and shows which consumers see the change. **Encryption At Rest** writes an `EncryptionConfiguration`, changes the kube-apiserver static pod and proves in `etcd` that the data is encrypted.

## Learning objectives

After this module you can:

- Explain why base64 in a Secret is not protection, and decode a Secret value.
- Check which identity can read Secrets with `kubectl auth can-i`.
- Deliver a Secret to a container as an environment variable and as a volume, and set the file mode of the volume.
- Rotate a Secret and make every consumer use the new value.
- Write an `EncryptionConfiguration` for the Secret resource, order its providers, and verify encryption in `etcd`.

## Before you start

You need Kubernetes basics: Pods, namespaces, volumes, and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You need a Linux shell and `sudo` for the encryption steps. You do not need any earlier module.

Your playground is a VM (virtual machine) that runs a one-node Kubernetes 1.35 cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods, so you can change the kube-apiserver and read the `etcd` data on it. The cluster has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `shuttle` client pod and the Secret `practice-token` with the disposable value `disposable-v1` |
| `outpost` | `drifter`, a `busybox` client pod |

Open a shell on the VM with `astrona ssh astro-ats-034-playground-020-01`. You are logged in as the `student` user, and `kubectl` already points at the cluster. Node files and processes belong to root, so run node commands with `sudo`. Every file you save is a file in the home directory of `student` on the VM.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
