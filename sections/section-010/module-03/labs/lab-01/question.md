---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage Pod Security Labels On Two Namespaces

Label two namespaces with different Pod Security profiles and prove the effect without disturbing the running Pods.

## Starting state

Neither `starfleet` nor `outpost` has Pod Security labels. The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs the `drifter` client Pod. All of these Pods run as root and have no security settings.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-ats-034-lab-010-03-01" || exit 1
node_name="astro-ats-034-lab-010-03-01-control-plane"
worker_name="astro-ats-034-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Set these labels and keep every existing label.

1. Namespace `starfleet` enforces Baseline, and it warns and audits on Restricted. Pin the version of all three modes to `v1.35`.
2. Namespace `outpost` enforces Restricted, pinned to `v1.35`.

Do not change any workload. When you finish, a Pod without security settings is admitted in `starfleet` and rejected by Pod Security Admission in `outpost`, a privileged Pod is rejected in both, and the `probe`, `shuttle` and `drifter` Pods are still Ready.

## Verify The Result

The grader checks the namespace labels and runs server-side dry runs. A rejection for any other reason, such as a missing namespace or a malformed request, does not count. Preserve the workloads and the `project` labels.
