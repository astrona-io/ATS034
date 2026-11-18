---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Pod That Meets Restricted With A Read-Only Root

Allow about 10 minutes for the tasks.

The `reader` workload must run in a namespace that enforces Restricted. It must not be able to change its own image files, but it needs one directory for scratch files.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-01-02` exists and enforces the Restricted profile, pinned to version `v1.35`. It runs no Pods.

## Tasks

1. In `starfleet-034-010-01-02`, create the Pod `reader` with one container named `reader`. It runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity`.
2. Run the process as user ID `1000` and refuse to run it as root.
3. Give the Pod everything else that Restricted requires: the `RuntimeDefault` seccomp profile, no privilege escalation and all capabilities dropped.
4. Mount the container's root filesystem read-only.
5. Mount an `emptyDir` volume named `scratch` at `/scratch`, so the process can still write files there.
6. Do not change the labels of the namespace.

## Check your work

```sh
kubectl -n starfleet-034-010-01-02 exec reader -- id
kubectl -n starfleet-034-010-01-02 exec reader -- grep -E 'NoNewPrivs|Seccomp:|CapEff' /proc/1/status
kubectl -n starfleet-034-010-01-02 exec reader -- touch /tmp/test-file
kubectl -n starfleet-034-010-01-02 exec reader -- touch /scratch/test-file
```

The process must run as `uid=1000`. `NoNewPrivs` must be `1`, `Seccomp` must be `2` and `CapEff` must be all zeros. The write to `/tmp` must fail with `Read-only file system`, and the write to `/scratch` must succeed.
