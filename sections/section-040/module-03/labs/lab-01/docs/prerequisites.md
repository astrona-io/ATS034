---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prerequisites

Use a host shell with astrona, kubectl, Helm and Python 3. Helm is the package manager for Kubernetes; it installs and upgrades a chart, which is a package of Kubernetes objects with settings called values.

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.
