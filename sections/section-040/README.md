---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Implement Pod-to-Pod encryption (Cilium, Istio)

A proxy encrypts a connection to another workload, but that workload still permits an unauthorized application operation. Transport authentication and application authorization answer different questions.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish encrypted transport, peer authentication and authorization.
- Explain where mesh components implement communication policy.
- Relate certificate rotation and hop boundaries to trust.
- Identify residual application and retry requirements.
