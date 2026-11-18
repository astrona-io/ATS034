---
exam_objectives:
- Manage Kubernetes secrets
---
# Prerequisites

Use a host shell with astrona and kubectl.

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.
