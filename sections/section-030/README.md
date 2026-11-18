---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)

Two untrusted applications can run in different namespaces and still share one node and one Linux kernel. A namespace groups names and permissions. It does not give a separate kernel, a separate node or a separate network. This section adds those boundaries one layer at a time and shows, on real clusters, which component enforces each one.

The section has three modules. The first module builds the tenant boundary inside one cluster with namespaces, RBAC (role-based access control), ResourceQuota, LimitRange, NetworkPolicy and a Pod without an API token, and then introduces sandboxed runtimes with RuntimeClass. The second module follows a Pod from the kubelet to the low-level runtime, compares gVisor and Kata Containers, adds scheduling and overhead to a RuntimeClass and makes the API server refuse Pods that skip the sandbox. The third module reserves a node for one tenant with labels, taints and tolerations, protects the labels with the NodeRestriction admission plugin, forces the placement at admission and compares the boundaries.

Each module starts with a landing page and its own playground, a private cluster that stays up while you read. A graded task follows most parts. Each task runs in its own cluster, checks the live result and gives a score. Each module ends with a summary and a knowledge check.

## Learning Outcomes

- Distinguish namespaced API separation from kernel isolation.
- Limit a tenant with RBAC, a ResourceQuota, a LimitRange, a NetworkPolicy and a Pod without a token.
- Compare shared-kernel, sandboxed-runtime and dedicated-node boundaries.
- Explain RuntimeClass prerequisites, scheduling and overhead.
- Reserve and protect dedicated nodes for one tenant.
- Require the sandbox class and node placement at admission.
