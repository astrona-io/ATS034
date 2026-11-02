---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Pod Security Standards And Admission

A Pod can ask the kubelet for almost anything on the node: a privileged container, the host network, a host directory, root in the container. Kubernetes accepts all of it unless something checks the request. Pod Security Admission is the built-in check. It compares each Pod with one of three fixed sets of rules, called the Pod Security Standards, and it accepts or rejects the Pod before it is stored.

This module explains the three standards, the `securityContext` fields that make a Pod meet them, and the namespace labels that switch the check on. You will test each profile with server-side dry-run requests, so you see the real rejection messages without leaving objects behind. You will also see why a Deployment can be accepted while its Pods are not, and how to find the reason.

The module has four parts. **The Three Pod Security Standards** compares Privileged, Baseline and Restricted and tests them with a privileged Pod and a plain Pod. **Security Context Fields** shows how to write a Pod that meets Restricted and how to give a read-only application a writable directory. **Pod Security Admission Modes** explains the `enforce`, `audit` and `warn` labels and the version pin, and ends with a graded task. **Admission For Workloads And Troubleshooting** follows a rejected Deployment through its ReplicaSet and covers exemptions and checks on existing namespaces.

## Learning objectives

After this module you can:

- Compare the Privileged, Baseline and Restricted profiles and name what each one forbids.
- Write a Pod `securityContext` that meets the Restricted profile and still gives the application a writable path.
- Label a namespace with the `enforce`, `audit` and `warn` modes and pin a profile to a Kubernetes version.
- Explain why a Deployment can be accepted while its Pods are rejected, and find the rejection reason.
- Check what a stricter label would break in an existing namespace before you apply it.

## Before you start

You need Kubernetes basics: Pods, namespaces, Deployments, labels and the commands `kubectl get`, `kubectl apply` and `kubectl describe`. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. It has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas), the `probe` Service on port 80, and `shuttle`, a `busybox` client pod |
| `outpost` | `drifter`, a `busybox` client pod |

Neither namespace has Pod Security labels, so Pod Security Admission applies no check to them. `kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
