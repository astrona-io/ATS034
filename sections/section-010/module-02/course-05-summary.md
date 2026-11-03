---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Summary

A container is a Linux process, so the kernel decides what it may do from its user ID, its capabilities, its system call filter and the parts of the node it can see. The Pod Security Standards check the Pod fields that control each of these.

The user comes from the `USER` instruction of the image unless the Pod sets `runAsUser` and `runAsGroup`. The field `runAsNonRoot` only checks the final user ID, and the kubelet raises `CreateContainerConfigError` when the ID is zero or when the image declares its user by name. The field `fsGroup` gives a non-root process write access to a mounted volume.

Capabilities split the power of root into named units. The container runtime gives each container a default set, and `drop: ["ALL"]` removes all of them. Restricted allows adding back only `NET_BIND_SERVICE`. The `CapEff` and `CapBnd` lines in `/proc/1/status` show what a process holds, and the line `NoNewPrivs` shows whether `allowPrivilegeEscalation: false` is in effect. A root process without capabilities cannot change file owners.

Seccomp filters system calls. The types are `RuntimeDefault`, `Localhost` and `Unconfined`. Baseline rejects `Unconfined`, and Restricted requires `RuntimeDefault` or `Localhost` to be set. AppArmor and SELinux add mandatory access control on the node. Baseline rejects an unconfined AppArmor profile and limits SELinux types, and the node must support them for the request to take effect.

Baseline also rejects the settings that expose the node: `hostNetwork`, `hostPID`, `hostIPC`, host ports and `hostPath` volumes. Restricted limits volumes to a short list of types. Most uses of `hostPath` can move to `emptyDir`, a ConfigMap, a Secret or a PersistentVolumeClaim. The key facts to remember are these:

- Admission checks the fields. The kubelet checks the real user ID, and the kernel enforces the capabilities and the filter.
- `readOnly: true` on a mount does not make a `hostPath` volume acceptable.
- A Deployment that fails Restricted shows the reason in the events of its ReplicaSet.
- Read `/proc/1/status` to confirm what a running container holds.

<!-- astrona:playground:destroy -->
