---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Summary

A sandbox request passes through a chain of components. The Pod names a class, the kubelet reads the handler of the `RuntimeClass` and sends it to the container runtime through the Container Runtime Interface, and containerd maps the handler name to a shim. The shim starts `runc`, `runsc` or a Kata virtual machine. A missing `RuntimeClass` object is rejected at creation. A missing handler leaves an accepted Pod in `ContainerCreating`.

gVisor puts a user-space kernel, the Sentry, between the application and the host kernel. It needs no virtualization, but it has slower system calls and incomplete compatibility. Kata Containers runs each Pod in a lightweight virtual machine with a guest kernel. It has strong separation and good compatibility, but it needs virtualization on the node and more memory. Neither replaces network policy, token control or quota.

The RuntimeClass admission plugin copies `overhead.podFixed` into the Pod and merges `scheduling.nodeSelector` and tolerations. The scheduler and quota then count the overhead, and the Pod lands only on nodes with the matching label. A conflicting selector or overhead in the Pod is rejected. A node selector attracts, and a taint with a toleration only repels and permits.

Using the class is optional unless admission requires it. A `ValidatingAdmissionPolicy` with a CEL expression, applied by a binding, rejects Pods in selected namespaces that do not set the required class. It acts at creation, and it checks the requested name, not the real isolation.

- The handler name must match the node runtime configuration exactly.
- Check the sandbox on the node, not only in the Pod spec.
- Label nodes and install handlers together.
- A policy needs a binding, and enforcement can lag by seconds.

<!-- astrona:playground:destroy -->
