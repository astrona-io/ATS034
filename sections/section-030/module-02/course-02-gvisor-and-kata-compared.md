---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# gVisor And Kata Compared

Both common sandboxes promise a stronger boundary than an ordinary container, but they build that boundary in different places. The choice changes performance, compatibility and node requirements. This part explains where each boundary sits, what each one costs, and how to decide, so that a `RuntimeClass` is chosen for a reason and not by habit.

## The boundary of an ordinary container

An ordinary container is a Linux process with restrictions: namespaces limit what it can see, control groups limit what it can use, and a seccomp filter limits which system calls it can make. Every allowed system call still runs in the host kernel. A bug in any allowed call gives the container code the privileges of the kernel. The sandboxes below put another layer between the application and the host kernel.

## gVisor: a kernel written in user space

**gVisor** intercepts the system calls of the application. Its component called the **Sentry** is a kernel written in Go that runs as an ordinary process. The Sentry implements the Linux system call interface itself, including the file system and the network stack. It makes only a small set of calls to the host kernel. A bug in the application's system calls reaches the Sentry, not the host kernel.

The runtime binary is `runsc`. It does not need hardware virtualization, so it runs on most cloud virtual machines. Its costs are slower system calls, slower file and network input and output, and some system calls and `/proc` entries that it does not implement. An application that needs an unsupported feature fails or behaves differently.

## Kata Containers: a virtual machine for each Pod

**Kata Containers** starts every Pod in a lightweight virtual machine with its own guest kernel. A hypervisor, such as QEMU or Cloud Hypervisor, separates the guest from the host. The containers of the Pod run inside the guest, so a kernel bug in the application's calls stays in the guest kernel.

The boundary is hardware-enforced virtualization, which gives strong separation and good compatibility, because the guest runs a real Linux kernel. The costs are a longer start time, extra memory for the guest kernel and the agent, and the need for virtualization support on the node. Many cloud instance types do not expose it without nested virtualization.

```mermaid
flowchart TB
  A["Application"] -->|"runc"| K["Host kernel"]
  B["Application"] -->|"runsc"| S["Sentry"]
  S -->|"few calls"| K
  C["Application"] -->|"kata"| G["Guest kernel"]
  G -->|"hypervisor"| K
```

The diagram shows that the three runtimes differ in what stands between the application and the host kernel: nothing, a user-space kernel, or a guest kernel.

## Compare the runtimes on the playground

The playground has only `runc`, which lets you see the baseline that sandboxes change. Save this as `pod-kernel-check.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kernel-check
  namespace: tenant-b
spec:
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply it and wait:

```sh
kubectl apply -f pod-kernel-check.yaml
kubectl -n tenant-b wait --for=condition=Ready pod/kernel-check --timeout=120s
```

Print the kernel release seen by the container, then the release seen by the node:

```sh
kubectl -n tenant-b exec kernel-check -- uname -r
kubectl get node -o jsonpath='{.items[*].status.nodeInfo.kernelVersion}'
```

The values match, because the container uses the host kernel directly. On a node with gVisor, the same `uname -r` inside a sandboxed Pod reports the version that the Sentry presents, which differs from the node. In a Kata Pod it reports the guest kernel. This difference is the simplest observation that a boundary exists.

## Choosing between them

Use gVisor when nodes are virtual machines without nested virtualization, and the workload uses common system calls. Use Kata Containers when the application needs full Linux compatibility, or when the strongest separation is required and the nodes support virtualization. Test the real application on the sandbox before the decision. A passing test proves compatibility. It does not prove that the application is free of bugs.

Neither sandbox protects against every attack. A stolen ServiceAccount token, an open network path and an unlimited resource request work the same in a sandbox. Sandboxes also do not change who can create Pods: a user who may create Pods can leave out the class.

You can now compare the two boundaries and their costs. A sandbox needs nodes that have it, and it needs extra memory. The next part shows how a `RuntimeClass` places Pods on the right nodes and accounts for that cost.

## Common pitfalls

> [!WARNING]
> - **Calling a sandbox a replacement for the other layers.** Network policy, token control and quota still apply.
> - **Choosing gVisor without testing the application.** An unimplemented system call fails at run time, not at admission.
> - **Choosing Kata on nodes without virtualization.** The Pod cannot start where the hypervisor cannot run.
> - **Reading equal `uname -r` values as a sandbox.** Equal values on a node mean the container shares the host kernel.
