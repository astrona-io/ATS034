---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prerequisites

Use `astrona`, `kubectl`, `openssl`, Python 3 and a shell. A kubeconfig identifies the cluster and credentials that `kubectl`, the Kubernetes command-line tool, uses.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection selected.
