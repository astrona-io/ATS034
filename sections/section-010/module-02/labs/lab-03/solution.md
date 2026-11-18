---
exam_objectives:
- Use appropriate pod security standards
---
# Attach A Localhost Seccomp Profile And An AppArmor Profile Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-02-03
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-034-lab-010-02-03
```

Keep this shell for the whole task. Every script of the lab refuses to run against another context.

Look at the starting state first. The file `/proc/1/status` in the container shows the seccomp mode of its first process, and `/proc/1/attr/current` shows its AppArmor profile:

```sh
ls -l /opt/profiles
kubectl -n starfleet-034-010-02-03 exec scout -- grep Seccomp: /proc/1/status
kubectl -n starfleet-034-010-02-03 exec scout -- cat /proc/1/attr/current
```

```text
total 8
-rw-r--r-- 1 root root 143 Nov 18 11:58 block-mkdir.json
-rw-r--r-- 1 root root 179 Nov 18 11:58 k8s-deny-tmp-write
Seccomp:	0
cri-containerd.apparmor.d (enforce)
```

`Seccomp: 0` means that no seccomp filter is active. The AppArmor profile `cri-containerd.apparmor.d` is the default profile that containerd, the container runtime, gives every container. Neither of the two new profiles is in use yet.

## Place the seccomp profile

The kubelet, the node agent that starts the containers, resolves a `Localhost` seccomp profile as a path below `/var/lib/kubelet/seccomp`. On this node the directory does not exist yet:

```sh
sudo ls /var/lib/kubelet/seccomp
```

```text
ls: cannot access '/var/lib/kubelet/seccomp': No such file or directory
```

`install -D` creates the missing directories and copies the file in one step:

```sh
sudo install -D -m 0644 /opt/profiles/block-mkdir.json /var/lib/kubelet/seccomp/profiles/block-mkdir.json
sudo ls -l /var/lib/kubelet/seccomp/profiles
```

```text
total 4
-rw-r--r-- 1 root root 143 Nov 18 12:02 block-mkdir.json
```

The Pod field will hold the path relative to `/var/lib/kubelet/seccomp`, that is `profiles/block-mkdir.json`.

## Load the AppArmor profile

AppArmor profiles do not live in a kubelet directory. The kernel must have the profile loaded before the container starts. `apparmor_parser -r` loads the file, or replaces the profile if it is already loaded:

```sh
sudo apparmor_parser -r /opt/profiles/k8s-deny-tmp-write
sudo grep k8s-deny /sys/kernel/security/apparmor/profiles
```

```text
k8s-deny-tmp-write (enforce)
```

The kernel lists the profile in enforce mode, so it blocks the actions it denies. The Pod field uses the profile name from inside the file, `k8s-deny-tmp-write`, not a file path.

## Replace the Pod

The security settings of a container cannot change in place. A `kubectl apply` on the running Pod fails with `The Pod "scout" is invalid: spec: Forbidden: pod updates may not change fields other than ...`. So the Pod must be deleted and created again. Save this as `pod-scout.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scout
  namespace: starfleet-034-010-02-03
  labels:
    app: scout
spec:
  containers:
  - name: scout
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/block-mkdir.json
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-tmp-write
```

Delete the old Pod and apply the new one:

```sh
kubectl -n starfleet-034-010-02-03 delete pod scout
kubectl apply -f pod-scout.yaml
kubectl -n starfleet-034-010-02-03 wait --for=condition=Ready pod/scout --timeout=120s
```

Then check the result:

```sh
kubectl -n starfleet-034-010-02-03 exec scout -- grep Seccomp: /proc/1/status
kubectl -n starfleet-034-010-02-03 exec scout -- cat /proc/1/attr/current
kubectl -n starfleet-034-010-02-03 exec scout -- mkdir /data
kubectl -n starfleet-034-010-02-03 exec scout -- sh -c 'echo test > /tmp/test'
```

```text
Seccomp:	2
k8s-deny-tmp-write (enforce)
mkdir: can't create directory '/data': Operation not permitted
command terminated with exit code 1
sh: can't create /tmp/test: Permission denied
command terminated with exit code 1
```

`Seccomp: 2` means that the kernel filters the system calls of the process. The seccomp filter returns `Operation not permitted` for `mkdir`. AppArmor returns `Permission denied` for the write below `/tmp`. The two different error texts show which kernel feature blocked each action. A write outside `/tmp`, for example `echo test > /test`, still works.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-02-03`.

## Common pitfalls

> [!WARNING]
> - `localhostProfile` is relative to `/var/lib/kubelet/seccomp`. With `block-mkdir.json` instead of `profiles/block-mkdir.json` the container does not start: the Pod shows `CreateContainerError` and the event says `cannot load seccomp profile "/var/lib/kubelet/seccomp/block-mkdir.json": open /var/lib/kubelet/seccomp/block-mkdir.json: no such file or directory`.
> - The AppArmor field takes the profile name, not the path `/opt/profiles/k8s-deny-tmp-write`.
> - Copying the AppArmor file somewhere is not enough. The kernel only knows the profile after `apparmor_parser` has loaded it.
> - Most Pod fields cannot be updated. Delete the Pod before you apply the new version.
