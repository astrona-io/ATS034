---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)

Two untrusted applications use different namespaces but share the same node kernel. Namespace organization alone does not supply a separate host trust boundary.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

The section has three modules and a capstone lab. The first module builds the tenant boundary with namespaces, RBAC, quota, network policy and token minimization. The second module goes deeper into sandboxed runtimes, RuntimeClass scheduling and overhead, and admission policy that requires the sandbox. The third module separates workloads by node with labels, taints and tolerations, protects the labels, forces placement at admission and compares the boundaries. The capstone lab combines the layers for one untrusted tenant.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish namespaced API separation from kernel isolation.
- Compare shared-kernel, sandboxed-runtime and dedicated-node boundaries.
- Explain RuntimeClass prerequisites and scheduling effects.
- Evaluate residual credentials, network and resource risks.
- Reserve and protect dedicated nodes for one tenant.
- Require the sandbox class and node placement at admission.
