---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Compose A Tenant Namespace Boundary

Combine admission, a resource budget, token minimization and network isolation for one tenant.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-01" || exit 1
node_name="astro-ats-034-lab-030-01-01-control-plane"
worker_name="astro-ats-034-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create tenant-a enforcing restricted Pod Security, a three-Pod ResourceQuota tenant-budget and a default-deny ingress/egress NetworkPolicy tenant-isolation. Run a Ready restricted tenant-reader with no token mount. Its attempted request to the healthy probe Service ClusterIP must time out. Namespace policies are layered controls, not a claim of separate-kernel isolation.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
