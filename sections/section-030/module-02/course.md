---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Sandboxed Runtimes, Scheduling And Enforcement

A Pod asks for a sandbox with one field, `runtimeClassName`. A long chain of components turns that field into a running sandbox: the kubelet, the Container Runtime Interface (CRI), the container runtime, a shim process and a low-level runtime such as `runc`, `runsc` (gVisor) or a Kata Containers runtime. If one link of the chain is missing, the Pod never starts. If the field is left out, the Pod runs on the ordinary runtime and nothing complains.

This module follows that chain. It shows where the runtime handler is configured on a node, compares the two common sandboxes, controls where sandboxed Pods run and what they cost, and then makes the cluster refuse Pods that do not ask for the sandbox.

The module has four parts. **The Runtime Handler Chain** follows a Pod from the kubelet to the low-level runtime. **gVisor And Kata Compared** explains how each sandbox places its boundary and what each costs. **RuntimeClass Scheduling And Overhead** merges node selectors, tolerations and fixed resources into Pods, and ends with a graded task. **Requiring The Sandbox With Admission Policy** rejects Pods that omit the class.

## Learning objectives

After this module you can:

- Name each component between the `runtimeClassName` field and a running sandbox, and say which one reads the handler name.
- Find the registered runtime handlers on a node.
- Compare gVisor and Kata Containers by boundary, cost and node requirements.
- Write a `RuntimeClass` with `scheduling` and `overhead`, and predict the fields the API server adds to a Pod.
- Write a `ValidatingAdmissionPolicy` that rejects Pods without the required `runtimeClassName`.

## Before you start

You need Pods, namespaces, labels, node labels and the commands `kubectl get`, `kubectl apply` and `kubectl describe`. You also need to know what a `RuntimeClass` is: a cluster-scoped object that maps a name to a runtime handler. You do not need an earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Its nodes run containerd with the default `runc` handler only. No gVisor or Kata handler is installed, because both need host features that a nested playground cannot give. The module therefore uses the `runc` handler under a new class name to show every field and every admission effect, and it states plainly where a real sandbox would behave differently.

The namespace `tenant-b` exists and is empty. `kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
