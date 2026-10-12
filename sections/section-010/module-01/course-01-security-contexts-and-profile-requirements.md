---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Security Contexts And Profile Requirements

An application runs as a non-root user but still needs a writable temporary directory. Making its root filesystem read-only does not create that directory. Hardening must restrict unnecessary behavior while preserving the files and operations the application needs.

## Learning objectives

- Compare Privileged, Baseline and Restricted profiles.
- Explain the purpose and limits of security-context fields.
- Relate image users and writable paths to profile compatibility.

## Before you start

This chapter is standalone reading material; no running cluster or installed tools are required. A Pod is the Kubernetes unit for running one or more containers, and a namespace groups namespaced objects. Treat the worked configurations as teaching examples rather than recorded observations from a provisioned environment.

## Responsible components and behavior

The `scout` process serves requests without needing host administration. A security context describes execution privileges and related settings for a Pod or container. Settings can require a non-root user, prevent privilege escalation, drop Linux capabilities and make the root filesystem read-only where the application supports it.

Linux capabilities divide selected privileged operations into smaller permissions. Dropping unnecessary capabilities reduces what a compromised process can do. A seccomp profile restricts permitted system calls. These controls complement ordinary file permissions and application checks; they do not repair a vulnerable application by themselves.

A read-only root filesystem can prevent writes to the image filesystem, but the application may still need writable temporary or data mounts. A non-root setting must match the image's user and file ownership requirements. Security configuration that prevents startup needs a suitable application design rather than simply being removed without analysis.

Pod Security Standards define Privileged, Baseline and Restricted profiles. Privileged allows broad behavior. Baseline prevents common privilege escalations while permitting many workloads. Restricted applies stronger hardening requirements. Pod Security Admission can enforce, warn about or audit these requirements through namespace configuration.

The profile is an admission rule, not a runtime process that automatically rewrites all applications into compliant ones. Enforcement can reject a new Pod. Warning reports a concern without the same rejection behavior. Version selection matters when comparing profile requirements across Kubernetes releases.

If an authorized developer cannot create a privileged workload in a Restricted namespace, the failure is expected admission behavior. The correct response is to design a compliant workload or obtain a justified exception through the platform's policy, not to assume role-based access control (RBAC) authentication failed.

## Combining Execution Controls

A non-root process reduces reliance on privileged file access, but its numeric user and group must be compatible with the files it needs. An image that stores writable application data under a root-owned directory may fail after the identity is restricted. A suitable writable volume and ownership plan can preserve both application operation and the protection.

Preventing privilege escalation helps prevent a process from gaining additional privilege through execution mechanisms. Dropping capabilities removes selected privileged operations. Seccomp filters system calls. A read-only root filesystem limits writes to the image filesystem. Each constrains a different behavior, so one setting does not imply all the others are active.

These controls also have scope. A Pod-level context can supply defaults, while container-level settings can apply to individual processes where supported. A helper needing one specific capability should not automatically make every container privileged. Read the effective configuration of each container, including init containers and supporting helpers.

## Admission Profiles And Actual Runtime Protection

A namespace can enforce a Pod Security profile, warn on another selected level and audit violations for review. Enforcement affects acceptance of the relevant Pod configuration. Warning and audit can support migration toward stronger policy without behaving identically to enforcement. Merely enabling audit mode does not mean violating Pods are rejected.

The profile version should be deliberate because requirements can evolve with Kubernetes. A change to enforcement can affect newly admitted Pods and future replacements, so a workload that previously ran is not proof that its next Pod will pass the current policy.

Admission checks validate a declared configuration; runtime controls enforce that configuration during execution. Application authorization, secret handling and vulnerability management remain necessary even for a profile-compliant Pod. Explain a protection through what it restricts, where it acts and which threat remains outside its boundary.

## Work through the decision

A security context configures supported process and Pod execution controls. A non-root identity limits reliance on privileged user access; capabilities grant selected Linux privileges; seccomp filters system calls; and a read-only root filesystem restricts writes to image storage. Each acts on a different behavior.

The Pod can supply defaults, while supported container fields can override relevant settings for one process. Inspect both levels before deciding which value applies. A required writable path may belong on an explicit volume with suitable ownership. Removing the read-only setting changes the protection boundary, whereas supplying the needed writable mount can preserve it.

```mermaid
flowchart TB
    P["Pod execution defaults"] --> E["Effective container settings"]
    C["Container-specific settings"] --> E
    E --> U["Process identity"]
    E --> S["System-call restrictions"]
    E --> F["Filesystem access"]
    U --> A["Supported application operation"]
    S --> A
    F --> A
```

Several independent controls combine into an execution contract that must still support the application.

You can now explain what a hardening field restricts and which application requirements must remain possible. Passing admission does not replace verification of actual startup and behavior under those restrictions.

## Common pitfalls

> [!WARNING]
> A security context must fit the application. Pod Security enforcement rejects disallowed configurations; it does not automatically repair them or replace application programming interface (API) permissions.
