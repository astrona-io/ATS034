---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prerequisites

Use `astrona`, `kubectl` and a shell. Select the private kubeconfig of this independent `kind` environment. A kubeconfig identifies the cluster and credentials that `kubectl`, the Kubernetes command-line tool, uses.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-040" || exit 1
```

Keep this connection selected. The cluster does not run Cilium, so the Cilium result is a values file.
