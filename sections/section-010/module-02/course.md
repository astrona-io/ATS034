---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Harden Container Privileges

A container process is a normal Linux process on a node. What it may do depends on four things: the user it runs as, the Linux capabilities it holds, the system calls its seccomp filter allows, and how much of the node it can see. Each of these has a field in the Pod spec, and each is checked by the Pod Security Standards. This module teaches the fields one group at a time, shows what the kernel does with each, and ends with the host settings that Baseline forbids.

The module has four parts. **Run As A Non-Root User** covers user and group IDs, `runAsNonRoot` and `fsGroup`, and the failure that appears when an image runs as root. **Capabilities And Privilege Escalation** shows what `drop: ["ALL"]` removes and what `allowPrivilegeEscalation: false` sets. **Seccomp, AppArmor And SELinux Settings** covers the profile fields and the values each profile accepts, and ends with a graded task in which you repair a Deployment so that it meets Restricted. **Host Namespaces And Host Paths** tests the settings that give a Pod a view of the node.

## Learning objectives

After this module you can:

- Choose `runAsUser`, `runAsGroup`, `runAsNonRoot` and `fsGroup` for a workload, and explain why `runAsNonRoot` alone can leave a Pod unable to start.
- Show with `/proc/1/status` which capabilities a container holds and whether `no_new_privs` is set.
- Set a seccomp profile and tell which values Baseline and Restricted accept.
- Explain what the AppArmor and SELinux fields control and which values the profiles forbid.
- Name the host namespace, port and volume settings that Baseline rejects and replace a `hostPath` volume with an allowed volume type.

## Before you start

You need Pods, namespaces, Deployments and the commands `kubectl apply`, `kubectl exec` and `kubectl describe`. You should know that a Pod Security Admission label on a namespace selects a profile, and that the Restricted profile needs a non-root user, a seccomp profile, dropped capabilities and no privilege escalation.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. These namespaces and workloads exist when it starts:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas), the `probe` Service on port 80, and `shuttle`, a `busybox` client pod |
| `outpost` | `drifter`, a `busybox` client pod |
| `hardened` | Enforces Restricted. The `scanner` Deployment runs as root and has no Ready Pods |

`kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
