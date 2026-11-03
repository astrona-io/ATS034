---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Prerequisites

Use astrona, kubectl, Python 3, Podman and a shell. Node inspection exercises use the containers in this environment, not the physical host.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-020" || exit 1
node_name="astro-ats-034-capstone-020-control-plane"
```

Keep this connection selected. Every script supplied by the lab refuses a different context.
