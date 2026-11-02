---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumer

Replace a disposable credential and verify both delivery paths use the new value.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-01" || exit 1
node_name="astro-ats-034-lab-020-01-01-control-plane"
worker_name="astro-ats-034-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Update Secret practice-token from disposable-v1 to disposable-v2. Create rotated-reader with the required environment key reference and read-only Secret volume at /credentials. Both values must equal the new disposable credential without printing it. An environment consumer must be recreated to load a changed Secret; a mounted projection has different update behavior.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
