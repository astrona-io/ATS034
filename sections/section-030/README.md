---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)

Two untrusted applications use different namespaces but share the same node kernel. Namespace organization alone does not supply a separate host trust boundary.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish namespaced API separation from kernel isolation.
- Compare shared-kernel, sandboxed-runtime and dedicated-node boundaries.
- Explain RuntimeClass prerequisites and scheduling effects.
- Evaluate residual credentials, network and resource risks.
