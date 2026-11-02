---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Restricted Pod Admission

Admit a compliant Pod and reject a privileged Pod through the API server.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-01" || exit 1
node_name="astro-ats-034-lab-010-01-01-control-plane"
worker_name="astro-ats-034-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Label namespace `restricted` with restricted Pod Security enforcement pinned to v1.35. Run the supplied non-root reader with RuntimeDefault seccomp, no privilege escalation and dropped capabilities. A server-side dry-run privileged Pod creation must be rejected specifically by Pod Security admission. The compliant reader must remain Ready.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
