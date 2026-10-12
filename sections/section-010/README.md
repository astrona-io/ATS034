---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Use appropriate pod security standards

An application runs as a non-root user but still needs a writable temporary directory. Making its root filesystem read-only does not create that directory. Hardening must restrict unnecessary behavior while preserving the files and operations the application needs.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Compare Privileged, Baseline and Restricted profiles.
- Explain the purpose and limits of security-context fields.
- Relate image users and writable paths to profile compatibility.
- Distinguish compliant configuration from complete application security.
