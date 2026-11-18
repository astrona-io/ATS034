---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Case Study

A tenant uploads build scripts that the platform team cannot review. Namespaces, RBAC (role-based access control) and NetworkPolicy already separate the tenant at the API and network level. A container that uses the default `runc` handler still makes its system calls to the kernel of the node, so a kernel bug can reach every other Pod on that node.

The node already has gVisor installed and registered in containerd under the handler name `runsc`. The remaining work is in Kubernetes: a RuntimeClass that maps a name to that handler, and a Pod that selects the class. The proof does not come from the Pod spec, which only shows what the Pod asked for. It comes from inside the Pod, where `dmesg` shows the gVisor kernel log, and from containerd, which reports the handler it used.
