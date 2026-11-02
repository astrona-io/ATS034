---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Summary

Kubernetes accepts any Pod spec unless a check rejects it. Pod Security Admission is that check. It is an admission controller in the API server, enabled by default since Kubernetes 1.25, and it replaced PodSecurityPolicy, which no longer exists.

The Pod Security Standards define three profiles. Privileged has no restrictions. Baseline forbids the settings that give a container access to the node, such as `privileged`, host namespaces, `hostPath` volumes, extra capabilities and an unconfined seccomp profile. Restricted adds the rules for hardening: `allowPrivilegeEscalation: false`, non-root users, a seccomp profile of `RuntimeDefault` or `Localhost`, dropped capabilities and a short list of volume types. No profile requires a read-only root filesystem.

An administrator selects the profile for a namespace with labels of the form `pod-security.kubernetes.io/<mode>` where the mode is `enforce`, `audit` or `warn`. Only `enforce` rejects a Pod. `warn` prints a warning in the client, and `audit` writes an annotation to the audit log. Each mode has a `-version` label that pins the rules to a Kubernetes minor version, and `latest` follows the cluster. A namespace without labels uses the cluster default, which is Privileged.

The Pod meets a profile through `securityContext` fields. Pod-level fields include `runAsNonRoot`, `runAsUser`, `fsGroup` and `seccompProfile`. Container-level fields include `allowPrivilegeEscalation`, `capabilities`, `privileged` and `readOnlyRootFilesystem`. A container-level value wins over the same field at the Pod level. A read-only root filesystem needs an `emptyDir` volume at each directory that the application writes to.

Admission checks Pod objects. A Deployment with a non-compliant template is accepted, and its ReplicaSet records a `FailedCreate` event for each rejected Pod. The `warn` and `audit` modes also check workload templates. Changing an `enforce` label never removes a running Pod, and a server-side dry run of the label change lists the existing Pods that would violate it. The key facts to remember are these:

- Test with `--dry-run=server`; a client-side dry run does not run admission.
- Roll out in order: `warn` and `audit` first, dry-run the `enforce` label, then enforce.
- A rejected Deployment shows its reason in the ReplicaSet events.
- Exemptions are part of the API server admission configuration, not namespace labels.

<!-- astrona:playground:destroy -->
