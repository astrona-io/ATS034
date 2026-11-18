---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Run A Pod Under gVisor With A RuntimeClass

Allow about 10 minutes for the tasks.

Tenant A runs code that the platform team does not trust. Its Pod must not share the kernel of the node with the other tenants.

## Starting state

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the Pods. Its container runtime, containerd, has two runtime handlers: `runc`, the default, and `runsc`, the runtime of gVisor. gVisor is a sandbox that runs a separate kernel in user space for each Pod. The namespaces `tenant-a-034-030-01-04` and `starfleet-034-030-01-04` exist, and `starfleet-034-030-01-04` runs the Pod `shuttle` with the default handler. No RuntimeClass exists.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-030-01-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-030-01-04`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells kubectl, the Kubernetes command-line tool, which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands such as `crictl` with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Create a RuntimeClass named `gvisor` that uses the runtime handler `runsc`.
2. Run the Pod `sandboxed` in `tenant-a-034-030-01-04` with `runtimeClassName: gvisor`, the image `docker.io/library/busybox:1.37.0` and the command `sleep infinity`. Wait until it is ready.
3. Prove that the Pod runs under gVisor and the `shuttle` Pod does not.

## Check your work

```sh
kubectl -n tenant-a-034-030-01-04 exec sandboxed -- dmesg
kubectl -n tenant-a-034-030-01-04 exec sandboxed -- uname -r
uname -r
sudo crictl pods --namespace tenant-a-034-030-01-04 --name sandboxed -o json | grep runtimeHandler
```

The `dmesg` output of the Pod must show the gVisor kernel log with `Starting gVisor`. The kernel version inside the Pod must differ from the version of the node. containerd must report the runtime handler `runsc` for the Pod sandbox. The grader runs the same checks and also checks that `shuttle` keeps the default handler.
