---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prerequisites

Use a host shell with astrona, kubectl, `openssl` and Python 3. The `openssl rand` command creates random bytes for a new key.

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.
