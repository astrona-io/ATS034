---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Applying Pod Security Requirements At Admission

A developer is authorized to create a Pod, but the requested privileged configuration violates the namespace's enforced policy. Pod Security Admission checks relevant Pod configuration against the selected Pod Security Standards profile. This is a distinct decision after identity and authorization, not a replacement for either.

## Three Modes With Different Effects

Enforce rejects violating configurations according to the selected policy. Warn provides feedback about violations without the same rejection behavior. Audit records violation information for observation and review. A namespace can configure these modes separately to support a controlled migration toward stronger restrictions.

For example, a platform can enforce Baseline while warning and auditing against Restricted. A workload allowed by Baseline can still receive Restricted feedback. That feedback is not proof it was rejected. Conversely, audit-only policy does not mean all violating Pods were prevented from running.

Policy version matters because profile requirements can evolve. A deliberately selected version provides a defined requirement set; an automatically advancing selection can change expectations when Kubernetes changes. Operators should understand the chosen contract and its upgrade implications rather than treating a profile name as timeless.

## Namespace Ownership And Workload Lifecycles

Namespace labels configure the applicable Pod Security behavior. An identity able to weaken those labels can affect the policy boundary. Control who can change policy configuration and record sensitive changes. Merely asking application authors to choose restrictive labels is insufficient when enforcement depends on untrusted authors retaining them.

A workload controller can request future Pods from its template. Existing workload behavior is not a guarantee that a new Pod will pass the current policy. Policy changes can affect replacements and updates, so assess template compatibility before enforcing a stronger requirement.

The admission system does not automatically rewrite incompatible images. A non-root requirement can expose incorrect file ownership, while a read-only filesystem needs suitable writable mounts. Fix the application's runtime contract or use a justified controlled exception rather than granting unrestricted privilege without analysis.

## Exceptions And Alternate Policy

Exemptions and other admission mechanisms can change the effective outcome where configured. An exemption should have a clear owner, narrow scope and reviewable justification. A broad exemption can make the visible namespace policy appear stronger than its actual effect.

Pod Security Admission evaluates defined configuration requirements. It does not verify every image signature, scan every dependency or authorize every application request. Other policy systems can add those decisions, but their implementation and failure behavior must be examined separately.

## A Policy Migration Scenario

Suppose a platform wants Restricted workloads, but several applications write to root-owned directories. Warn and audit evidence can identify affected templates before rejection becomes enforced. Authors can adapt images, users and mounts, verify compatibility in the actual operating process and then tighten enforcement through the platform's approved change workflow.

The evidence should show which requirements failed and how the resulting declarations meet them. A warning disappearing is useful but does not independently prove every business behavior still works. Security migration needs both compliant configuration and application compatibility.

A complete admission explanation identifies selected mode, profile, version, scope and exceptions. Those details distinguish an intended policy from the actual acceptance behavior a student must reason about.

## Common pitfalls

> [!WARNING]
> Warn and audit are not equivalent to enforce. Policy labels, versions and exemptions determine the effective decision, and compliance does not prove every aspect of workload safety.
