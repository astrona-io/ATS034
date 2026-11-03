---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Seccomp, AppArmor And SELinux Settings

A process asks the Linux kernel for everything through system calls: opening a file, creating a socket, loading a kernel module. A container usually needs a small part of the hundreds of system calls that exist. Kernel features that filter those calls reduce the attack surface of the kernel, so a bug in a rarely used system call is not reachable from a container. This part covers the seccomp profile field, which both Baseline and Restricted check, and the AppArmor and SELinux fields, which Baseline limits. The part ends with a graded task that combines every field from this module.

## Seccomp profiles

Seccomp (secure computing mode) is a kernel feature that filters the system calls of a process. A **seccomp profile** is the list of rules. In Kubernetes the field `seccompProfile` selects it, at the Pod level or at the container level. It has a `type`:

- `RuntimeDefault` uses the default profile of the container runtime. It blocks a set of system calls that ordinary applications do not need.
- `Localhost` uses a profile file on the node. The field `localhostProfile` gives the path relative to the kubelet seccomp directory. If the file does not exist on the node, the container does not start.
- `Unconfined` turns the filter off.

If a Pod sets no profile, the container runs unconfined unless the kubelet is started with the option that makes `RuntimeDefault` the default for the node. Do not rely on that option; a Pod that must be portable states its profile.

Baseline rejects `Unconfined`. A Pod without any profile passes Baseline. Restricted is stricter: the profile must be set explicitly, and the type must be `RuntimeDefault` or `Localhost`.

## Test the types

Create a namespace for the examples. It has no labels for the moment:

<!-- astrona:playground:renew -->

```sh
kubectl create namespace seccomp-demo
```

Save a Pod with the runtime default profile as `pod-seccomp-runtime.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime
  namespace: seccomp-demo
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Save a Pod with the filter switched off as `pod-seccomp-unconfined.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-unconfined
  namespace: seccomp-demo
spec:
  securityContext:
    seccompProfile:
      type: Unconfined
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply both and read the seccomp mode that the kernel reports for process 1:

```sh
kubectl apply -f pod-seccomp-runtime.yaml -f pod-seccomp-unconfined.yaml
kubectl -n seccomp-demo wait --for=condition=Ready pod/seccomp-runtime pod/seccomp-unconfined --timeout=120s
kubectl -n seccomp-demo exec seccomp-runtime -- grep Seccomp: /proc/1/status
kubectl -n seccomp-demo exec seccomp-unconfined -- grep Seccomp: /proc/1/status
```

The first container shows `Seccomp:` with the value `2`, which means a filter is active. The second shows `0`, which means no filter. Now put the namespace under Baseline and send the unconfined Pod again as a server-side dry run:

```sh
kubectl label namespace seccomp-demo pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl delete pod seccomp-unconfined -n seccomp-demo
kubectl apply -f pod-seccomp-unconfined.yaml --dry-run=server
```

The label command prints a warning that names the running `seccomp-unconfined` Pod, because it already breaks Baseline, and it still applies the label. The Pod is deleted before the dry run so that the request is a new Pod and not an update of a running one. The dry run fails with a `Forbidden` error that says the Pod violates `baseline:latest` and names `seccompProfile` with the value `Unconfined`. Baseline stops the one value that turns the filter off.

## AppArmor and SELinux

AppArmor and SELinux are Linux security modules. A security module applies mandatory access control: rules that the administrator sets on the node decide which files and operations a process may use, and the process cannot change them even as root. A node runs one or the other, depending on the Linux distribution.

For AppArmor, the Pod field `appArmorProfile` has a `type` of `RuntimeDefault`, `Localhost` (with a `localhostProfile` name loaded on the node) or `Unconfined`. Baseline rejects `Unconfined`. For SELinux, the field `seLinuxOptions` sets the label of the container process. Baseline allows the `type` values `container_t`, `container_init_t`, `container_kvm_t` and `container_engine_t`, and it rejects any `user` or `role` setting. Restricted adds no further rule for either module.

Both modules need support on the node. A Pod that asks for a `Localhost` AppArmor profile that is not loaded on its node does not start, and a Pod that asks for an SELinux label on a node without SELinux has no effect. The Pod spec records the request, and only the node can show whether it is enforced.

## Put the fields together

The task after this part combines the fields from this module. A Deployment in a namespace that enforces Restricted is accepted, but it has no Ready Pods. You read the reason in the events, then correct the Pod template with a non-root user, a seccomp profile, dropped capabilities, no privilege escalation and a read-only root filesystem with a writable volume.

The sequence to follow is the one you used for the earlier parts. Read the `FailedCreate` event, list the broken rules, change the template and check the live process. You now know the fields that Restricted needs. What is left are the settings that Baseline already forbids because they expose the node itself.

## Common pitfalls

> [!WARNING]
> - **Leaving the seccomp profile out under Restricted.** Baseline accepts a Pod without a profile, and Restricted does not.
> - **Choosing `Localhost` without placing the file on every node.** The container fails to start on a node that lacks the file.
> - **Assuming a profile field proves enforcement.** Read `/proc/1/status` for seccomp, and check the node for AppArmor or SELinux support.
> - **Setting `Unconfined` to silence an error.** It removes the filter. Find the system call that the application needs and use a custom `Localhost` profile instead.
