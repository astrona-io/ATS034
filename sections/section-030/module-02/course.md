---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Sandboxed Runtimes, Scheduling And Enforcement

A Pod asks for a sandbox with one field, `runtimeClassName`. A long chain of components turns that field into a running sandbox: the kubelet, the Container Runtime Interface (CRI), the container runtime, a shim process and a low-level runtime such as `runc`, `runsc` (gVisor) or a Kata Containers runtime. If one link of the chain is missing, the Pod never starts. If the field is left out, the Pod runs on the ordinary runtime and nothing complains.

This module follows that chain. It shows where the runtime handler is configured on a node, compares the two common sandboxes, controls where sandboxed Pods run and what they cost, and then makes the cluster refuse Pods that do not ask for the sandbox.

The module has four parts. **The Runtime Handler Chain** follows a Pod from the kubelet to the low-level runtime. **gVisor And Kata Compared** explains how each sandbox places its boundary and what each costs. **RuntimeClass Scheduling And Overhead** merges node selectors, tolerations and fixed resources into Pods. **Requiring The Sandbox With Admission Policy** rejects Pods that omit the class. A graded task follows the handler chain part, the scheduling part and the admission part.

## Learning objectives

After this module you can:

- Name each component between the `runtimeClassName` field and a running sandbox, and say which one reads the handler name.
- Find the registered runtime handlers on a node, register a missing one in containerd and prove which handler ran a Pod.
- Compare gVisor and Kata Containers by boundary, cost and node requirements.
- Write a `RuntimeClass` with `scheduling` and `overhead`, and predict the fields the API server adds to a Pod.
- Write a `ValidatingAdmissionPolicy` that rejects Pods without the required `runtimeClassName`.

## Before you start

You need Pods, namespaces, labels, node labels and the commands `kubectl get`, `kubectl apply` and `kubectl describe`. You also need to know what a `RuntimeClass` is: a cluster-scoped object that maps a name to a runtime handler. You do not need an earlier module.

Your playground is one virtual machine (VM) that runs a one-node Kubernetes 1.35 cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs your Pods. Its container runtime is containerd 2.2, with two runtime handlers: `runc`, the default, and `runsc`, the runtime of gVisor. So every sandboxed Pod in this module runs under real gVisor. Kata Containers is not installed, because it needs hardware virtualization inside the VM, so the module explains Kata without running it.

You work in a shell on the VM. The parts show how to open it with `astrona ssh`. You log in as the `student` user, which has `sudo` and a kubeconfig file for the cluster. The namespace `tenant-b` exists and is empty. Every file you save is a file on the VM, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

