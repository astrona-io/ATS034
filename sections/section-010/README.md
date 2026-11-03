---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Use appropriate pod security standards

An application runs as a non-root user but still needs a writable temporary directory. Making its root filesystem read-only does not create that directory. Hardening must restrict unnecessary behavior while preserving the files and operations the application needs.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

The section has three modules and a capstone. The first compares the three profiles and the admission modes. The second hardens container privileges: users, capabilities, privilege escalation, seccomp, mandatory access control, host namespaces and host paths. The third rolls Pod Security labels out across namespaces with staged changes, cluster defaults, exemptions and RBAC. The capstone applies all of it across three namespaces.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Compare Privileged, Baseline and Restricted profiles.
- Explain the purpose and limits of security-context fields.
- Relate image users and writable paths to profile compatibility.
- Distinguish compliant configuration from complete application security.
- Set a non-root user, drop capabilities and block privilege escalation, and read the result from the running process.
- Apply seccomp, AppArmor and SELinux settings, and avoid host namespaces and host paths.
- Inventory namespaces and stage a label change through warn, audit and enforce with pinned versions.
- Explain cluster defaults and exemptions, and place node-level workloads in their own namespace.
- Repair workloads and label several namespaces so each enforces the right profile.
