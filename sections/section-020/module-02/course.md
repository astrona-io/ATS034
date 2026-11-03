---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Secret Types, Pull Credentials And Access Control

Not every Secret is a generic bag of key-value pairs. Kubernetes defines types of Secret for TLS keys, registry credentials, basic authentication and ServiceAccount tokens, and the API server checks the keys of each type when you create the object. A Secret can also be marked immutable so that nobody can change it, and Role-Based Access Control (RBAC) can limit a workload to one named Secret. These three controls decide how a credential is created, how long it stays the same and who may read it.

This module teaches how to choose the right Secret type, how to give a workload a registry credential or a short-lived ServiceAccount token, how to freeze a Secret with the `immutable` field, and how to write a Role that reads one Secret and nothing else. Each idea is tried on the playground cluster with disposable credentials, so no real secret appears in a command.

The module has four parts. **Secret Types And How To Create Them** lists the built-in types, their required keys and the `kubectl create secret` commands. **Image Pull Secrets And ServiceAccount Tokens** shows how a Pod pulls from a private registry and why a bound token is safer than a token stored in a Secret. **Immutable Secrets** freezes a Secret and ends with a graded task. **Least-Privilege Access To Secrets** writes a Role with `resourceNames` and tests it with `kubectl auth can-i`.

## Learning objectives

After this module you can:

- Name the built-in Secret types, state the keys each one requires, and create a Secret of the right type.
- Create an image pull Secret and attach it to a Pod or a ServiceAccount.
- Explain why a bound ServiceAccount token is safer than a token stored in a Secret.
- Mark a Secret immutable, state what that prevents, and replace an immutable Secret safely.
- Write a Role that allows `get` on one named Secret, and test the result for a ServiceAccount.

## Before you start

You need Kubernetes basics: Pods, namespaces, volumes, and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You should know that a Secret stores its values as base64 in the field `data`.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. It has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas), the `probe` Service, the `shuttle` client pod, and the Secret `practice-token` with the disposable value `disposable-v1` |
| `outpost` | `drifter`, a `busybox` client pod |

`kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
