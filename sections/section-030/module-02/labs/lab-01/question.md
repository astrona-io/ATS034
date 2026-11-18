---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Register The gVisor Handler In containerd

Allow about 15 minutes for the tasks.

The `scout` Pod of tenant B must run under gVisor, but it has been stuck in `ContainerCreating` since it was created. The platform team says the RuntimeClass is correct.

## Starting state

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the Pods. gVisor is a sandbox that runs a separate kernel in user space for each Pod. Its binaries, `runsc` and `containerd-shim-runsc-v1`, are installed in `/usr/local/bin`.

containerd is the container runtime of the node. Its configuration file is `/etc/containerd/config.toml`, and it lists one runtime handler, `runc`. The RuntimeClass `gvisor` names the handler `runsc`. The Pod `scout` in `tenant-b-034-030-02-01` sets `runtimeClassName: gvisor`. The Pod `shuttle` in `starfleet-034-030-02-01` uses the default handler and is running.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-030-02-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-030-02-01`. You are logged in as the `student` user. The containerd files belong to root, so edit them and run `crictl` and `systemctl` with `sudo`. These commands change only the lab VM, not your own computer.

## Tasks

1. Find out which component keeps `scout` from starting, and why.
2. Register the runtime handler `runsc` in `/etc/containerd/config.toml` with `runtime_type = "io.containerd.runsc.v1"`. Keep the `runc` handler as it is.
3. Make containerd load the new configuration. Do not delete or change `scout` or the RuntimeClass.
4. Prove that `scout` now runs under gVisor and that `shuttle` still uses the default handler.

## Check your work

```sh
sudo crictl info | jq '.config.containerd.runtimes | keys'
kubectl -n tenant-b-034-030-02-01 get pod scout
kubectl -n tenant-b-034-030-02-01 exec scout -- dmesg
sudo crictl pods --namespace tenant-b-034-030-02-01 --name scout
```

containerd must list the handlers `runc` and `runsc`, and the handler must stay in the configuration file after a restart. `scout` must be `Running`, its `dmesg` output must show `Starting gVisor`, and the `RUNTIME` column of `crictl pods` must show `runsc`. The grader also checks that `shuttle` keeps the default handler.
