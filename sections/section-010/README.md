---
exam_objectives:
- Use appropriate pod security standards
---
# Use appropriate pod security standards

An application runs as a non-root user but still needs a writable temporary directory. Making its root filesystem read-only does not create that directory. Hardening must restrict unnecessary behavior while preserving the files and operations the application needs.

This section teaches the three Pod Security Standards, the `securityContext` fields that each standard checks, and how to roll the standards out across the namespaces of a running cluster without breaking the workloads in them.

## Learning Path

1. Pod Security Standards And Admission: the Privileged, Baseline and Restricted profiles, the `securityContext` fields, the `enforce`, `audit` and `warn` modes, and why a Deployment is accepted while its Pods are rejected.
2. Harden Container Privileges: non-root users, capabilities, privilege escalation, seccomp and AppArmor profiles, host namespaces and host paths.
3. Roll Out Pod Security Labels Across Namespaces: a dry-run inventory, a staged label change, cluster-wide defaults and exemptions in the admission configuration file, and who may change the labels.

Each module ends with a summary and a ten-question knowledge check. The parts carry the hands-on steps, and each graded lab follows the part that practises its skill. Most labs run in their own `kind` cluster with Kubernetes v1.35. The two labs that change files on the node, a seccomp and AppArmor profile and the API server admission configuration, run in their own virtual machine. Each module has a private playground; launch it from the landing page and keep it running while you read.

## Learning Outcomes

- Compare Privileged, Baseline and Restricted profiles.
- Explain the purpose and limits of security-context fields.
- Relate image users and writable paths to profile compatibility.
- Distinguish compliant configuration from complete application security.
- Set a non-root user, drop capabilities and block privilege escalation, and read the result from the running process.
- Apply seccomp, AppArmor and SELinux settings, and avoid host namespaces and host paths.
- Inventory namespaces and stage a label change through warn, audit and enforce with pinned versions.
- Explain cluster defaults and exemptions, and place node-level workloads in their own namespace.
- Repair a Deployment that Pod Security Admission blocks, and protect the namespace labels with RBAC.
