---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

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
