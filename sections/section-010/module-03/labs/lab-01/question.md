---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage Pod Security Labels On Two Namespaces

Solve this question on: `terminal`

Neither `starfleet-034-010-03-01` nor `outpost-034-010-03-01` has Pod Security labels. The `starfleet-034-010-03-01` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost-034-010-03-01` namespace runs the `drifter` client Pod. All of these Pods run as root and have no security settings.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-03-01" || exit 1
node_name="astro-ats-034-lab-010-03-01-control-plane"
worker_name="astro-ats-034-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Label the namespace `starfleet-034-010-03-01` so that it enforces Baseline and warns and audits on Restricted. Pin the version of all three modes to `v1.35`.
2. Label the namespace `outpost-034-010-03-01` so that it enforces Restricted, pinned to `v1.35`.
3. Prove the effect with server-side dry runs: a Pod without security settings is admitted in `starfleet-034-010-03-01` and rejected in `outpost-034-010-03-01`, and a privileged Pod is rejected in both.

## Constraints

- Keep every existing label, including the `project` labels.
- Do not change any workload. The `probe`, `shuttle` and `drifter` Pods must stay Ready.

## How the answer is checked

The grader runs one check per namespace. Each checks the namespace labels and sends Pods as server-side dry runs: a plain and a privileged Pod. Only a rejection by Pod Security admission counts; a rejection for another reason, such as a missing namespace or a malformed request, does not. Both checks also need the `probe`, `shuttle` and `drifter` Pods to be Ready.

Hint: Labelling a namespace does not evict running Pods. `kubectl label` prints a warning for each existing Pod that would violate the new level.
