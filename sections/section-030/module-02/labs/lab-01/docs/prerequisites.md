---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Prerequisites

Use a host shell with astrona. Everything else runs inside the lab VM (virtual machine): kubectl, crictl, systemctl and the cluster.

Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-030-02-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-030-02-01`. crictl is the command-line tool that talks to the container runtime of the node through the CRI (Container Runtime Interface). It needs root, so run it with `sudo`. You also need a text editor on the VM, such as `vi` or `nano`, and you edit the containerd configuration with `sudo`.
