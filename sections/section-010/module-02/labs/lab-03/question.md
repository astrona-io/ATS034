---
exam_objectives:
- Use appropriate pod security standards
---
# Attach A Localhost Seccomp Profile And An AppArmor Profile

Allow about 12 minutes for the tasks.

The `scout` Pod processes uploaded files. The security team wrote two kernel profiles for it: one that blocks the creation of directories and one that blocks writes to `/tmp`. Install both on the node and attach them to the Pod.

## Starting state

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the Pods. The namespace `starfleet-034-010-02-03` runs the Pod `scout`. It has one container named `scout` that runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity` and no security profiles.

Two profile files are ready in `/opt/profiles` on the node:

- `block-mkdir.json` is a seccomp profile. Seccomp is a Linux kernel feature that filters the system calls of a process. This profile allows every system call except `mkdir` and `mkdirat`.
- `k8s-deny-tmp-write` is an AppArmor profile with the same name inside the file. AppArmor is a Linux security module that limits which files a process may use. This profile denies every write below `/tmp`.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-02-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-010-02-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Copy `block-mkdir.json` to the place where the kubelet looks for `Localhost` seccomp profiles, in a subdirectory named `profiles`.
2. Load the AppArmor profile `k8s-deny-tmp-write` into the kernel of the node.
3. Change the `scout` container so that it uses the seccomp profile `profiles/block-mkdir.json` of type `Localhost` and the AppArmor profile `k8s-deny-tmp-write` of type `Localhost`. Use the `securityContext` fields, not annotations.
4. Keep the Pod name, the container name, the image and the command.

## Check your work

```sh
kubectl -n starfleet-034-010-02-03 exec scout -- grep Seccomp: /proc/1/status
kubectl -n starfleet-034-010-02-03 exec scout -- cat /proc/1/attr/current
kubectl -n starfleet-034-010-02-03 exec scout -- mkdir /data
kubectl -n starfleet-034-010-02-03 exec scout -- sh -c 'echo test > /tmp/test'
```

`Seccomp` must be `2`, the AppArmor line must name `k8s-deny-tmp-write (enforce)`, and both write commands must fail.
