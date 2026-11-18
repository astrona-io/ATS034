---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Prerequisites

Use a host shell with astrona, kubectl, Python 3 and the container engine that runs kind (Podman or Docker).

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-02" || exit 1
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context. Node commands run with `"$engine" exec "$cluster-worker"`, inside this lab's worker node container only.
