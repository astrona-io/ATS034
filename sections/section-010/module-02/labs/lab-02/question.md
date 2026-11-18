---
exam_objectives:
- Use appropriate pod security standards
---
# Drop All Capabilities And Block Privilege Escalation

Allow about 8 minutes for the tasks.

The `courier` Pod must keep running as root for an old tool, but the root user inside it must lose the special powers that root normally has.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-02-02` runs the Pod `courier`. It has one container named `courier` that runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity`, as user ID 0 with the default capabilities of the container runtime.

## Tasks

1. Remove every Linux capability from the `courier` container.
2. Set the container so that its process and its children can never gain more privileges than they started with.
3. Keep the Pod name, the container name, the image and the command. The process must still run as user ID 0.

## Check your work

```sh
kubectl -n starfleet-034-010-02-02 exec courier -- grep -E 'CapEff|CapBnd|NoNewPrivs' /proc/1/status
kubectl -n starfleet-034-010-02-02 exec courier -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned'
```

`CapEff` and `CapBnd` must be all zeros and `NoNewPrivs` must be `1`. The `chown` command must fail with `Operation not permitted`, even though the process runs as root.
