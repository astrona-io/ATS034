---
exam_objectives:
- Use appropriate pod security standards
---
# Seccomp, AppArmor And SELinux Settings

A process asks the Linux kernel for everything through system calls: opening a file, creating a socket, loading a kernel module. A container usually needs a small part of the hundreds of system calls that exist. Kernel features that filter those calls reduce the attack surface of the kernel, so a bug in a rarely used system call is not reachable from a container. This part covers the seccomp profile field, which both Baseline and Restricted check, and the AppArmor and SELinux fields, which Baseline limits.

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

## Install Localhost profiles on the node

The `Localhost` type moves work from the Pod to the node. An administrator places the seccomp file and loads the AppArmor profile on every node that may run the Pod, and only then does the Pod start. The playground node is the VM you are logged in to, so you run these steps there with `sudo`. The setup placed both profile files in `/opt/profiles`.

### Place a seccomp file

The kubelet, the node agent that starts the containers, reads a `Localhost` seccomp profile from a path below `/var/lib/kubelet/seccomp`. On a fresh kubeadm node the directory does not exist yet. `install -D` creates the directories and copies the file in one step:

```sh
sudo install -D -m 0644 /opt/profiles/block-mkdir.json /var/lib/kubelet/seccomp/profiles/block-mkdir.json
sudo ls -l /var/lib/kubelet/seccomp/profiles
```

```text
total 4
-rw-r--r-- 1 root root 143 Nov 18 13:20 block-mkdir.json
```

The Pod then sets `localhostProfile: profiles/block-mkdir.json`, the path relative to `/var/lib/kubelet/seccomp`. If the path is wrong, the kubelet cannot find the file, and the container stays in `CreateContainerError` with the event `cannot load seccomp profile "/var/lib/kubelet/seccomp/block-mkdir.json": open /var/lib/kubelet/seccomp/block-mkdir.json: no such file or directory`.

### Load an AppArmor profile

An AppArmor profile is not read from a kubelet directory. The kernel must have it loaded before the container starts. `apparmor_parser -r` loads a profile file, or replaces the profile when it is already loaded, and the kernel lists the loaded profiles in `/sys/kernel/security/apparmor/profiles`:

```sh
sudo apparmor_parser -r /opt/profiles/k8s-deny-tmp-write
sudo grep k8s-deny /sys/kernel/security/apparmor/profiles
```

```text
k8s-deny-tmp-write (enforce)
```

The Pod field `localhostProfile` takes the profile name from inside the file, here `k8s-deny-tmp-write`, not a file path. A profile loaded this way does not survive a reboot unless the file is also placed in `/etc/apparmor.d`, where the AppArmor service loads it at boot.

### Check the running process

The container fields from this part look like this when both profiles are attached:

```yaml
securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: profiles/block-mkdir.json
  appArmorProfile:
    type: Localhost
    localhostProfile: k8s-deny-tmp-write
```

After the Pod is created again with these fields, the process in the container reports both profiles, and each one blocks its own action:

```text
Seccomp:	2
k8s-deny-tmp-write (enforce)
mkdir: can't create directory '/data': Operation not permitted
sh: can't create /tmp/test: Permission denied
```

The first two lines come from `/proc/1/status` and `/proc/1/attr/current` inside the container. The seccomp filter returns `Operation not permitted` for `mkdir`, and AppArmor returns `Permission denied` for the write below `/tmp`, so the error text tells you which kernel feature stopped the action. This output is shortened: each failed command also prints `command terminated with exit code 1`.

You now know the three profile fields, which values Baseline and Restricted accept, and how a `Localhost` profile reaches the node. The fields in this part still let a container use the node directly through host namespaces, host ports and host paths, and Baseline forbids those settings for that reason.

## Common pitfalls

> [!WARNING]
> - **Leaving the seccomp profile out under Restricted.** Baseline accepts a Pod without a profile, and Restricted does not.
> - **Choosing `Localhost` without placing the file on every node.** The container fails to start on a node that lacks the file.
> - **Giving a full path or a file name in `localhostProfile`.** For seccomp it is the path relative to `/var/lib/kubelet/seccomp`; for AppArmor it is the profile name that `apparmor_parser` loaded.
> - **Assuming a profile field proves enforcement.** Read `/proc/1/status` for seccomp, and check the node for AppArmor or SELinux support.
> - **Setting `Unconfined` to silence an error.** It removes the filter. Find the system call that the application needs and use a custom `Localhost` profile instead.
