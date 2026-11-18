---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# gVisor Sandbox Playground

This ungraded playground is one virtual machine (VM) that runs a single-node Kubernetes 1.35 cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node `astro-ats-034-playground-030-02` is the control plane and also runs your Pods.

The node runs containerd 2.2, the container runtime that starts the Pods. gVisor is a sandbox that runs its own kernel in user space for each Pod. Its binaries, `runsc` and `containerd-shim-runsc-v1`, are installed in `/usr/local/bin`, and containerd registers them as the runtime handler `runsc` next to the default handler `runc`. Kata Containers is not installed.

## Connect to the node

You log in as the `student` user, which has `sudo` and a kubeconfig file for the cluster. A kubeconfig file tells kubectl, the Kubernetes command-line tool, which cluster to use and which credentials to send.

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-034-playground-030-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-playground-030-02`. Commands that use `sudo` change only this VM. They do not touch your own computer.

## What is in the playground

The namespace `tenant-b` exists and is empty. No RuntimeClass, ValidatingAdmissionPolicy or node label exists at the start, so you create every object yourself. Check the two handlers that containerd has loaded:

```sh
sudo crictl info | jq -r '.config.containerd.runtimes | keys[]'
```

The output lists `runc` and `runsc`. The containerd configuration file is `/etc/containerd/config.toml`. If you edit it, run `sudo systemctl restart containerd` so that containerd loads the change.

## Common pitfalls

> [!WARNING]
> - `crictl`, `systemctl` and the containerd files need `sudo`.
> - A broken `/etc/containerd/config.toml` stops containerd, and then no Pod can start. Copy the file before you edit it, and restore the copy if `sudo systemctl status containerd` shows a failure.
> - The ValidatingAdmissionPolicy `require-sandbox` with its binding `require-sandbox-tenant-b` denies every new Pod in `tenant-b` without `runtimeClassName: sandboxed`. Delete the binding when you want to create other Pods there.
> - The RuntimeClass `sandboxed` selects nodes with the label `sandbox=true`. Without that label on the node, its Pods stay `Pending`.
