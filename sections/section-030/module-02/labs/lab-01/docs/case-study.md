---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Case Study

A platform team installed the gVisor binaries on a node and created a RuntimeClass named `gvisor` with the handler `runsc`. The API server accepted the RuntimeClass and the tenant's Pod, because it does not know which handlers the nodes have. The kubelet then asked containerd for a Pod sandbox with the handler `runsc`, and containerd refused, because its configuration has no table with that name.

The fix is on the node, not in Kubernetes. containerd needs a runtime table named `runsc` whose `runtime_type` selects the gVisor shim, and it reads that table only when it starts. After the restart, the kubelet retries the sandbox on its own, and the Pod starts without any change to the Pod or the RuntimeClass. The proof comes from containerd, which reports the handler it used, and from `dmesg` inside the Pod, which shows the gVisor kernel log.
