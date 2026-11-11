---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Apply Pod Security Standards Across Three Namespaces

Correct two workloads and label three namespaces so each namespace enforces the right profile and the applications keep running.

## Starting state

The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs the `drifter` client Pod. The `dock` namespace enforces Restricted at v1.35 and holds the `scout` Deployment, which has one replica and no Ready Pod. `starfleet` and `outpost` have no Pod Security labels. All workloads run as root with no security settings.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-010)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-010" || exit 1
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Three teams share one cluster. Each namespace needs its own decision, and no application may stop working.

1. Repair the `probe` Deployment in `starfleet`. Keep its replicas, selector, image, command, readiness probe and volume. The Pod template must have `runAsNonRoot: true`, `runAsUser: 1000` and a `RuntimeDefault` seccomp profile at the Pod level, and `allowPrivilegeEscalation: false` with all capabilities dropped in the container.
2. Repair the `scout` Deployment in `dock` with the same Pod-level and container-level fields, plus `readOnlyRootFilesystem: true`. The container writes `/scratch/state`, so add an `emptyDir` volume named `scratch` mounted at `/scratch`. Do not change the labels of `dock`.
3. Label `starfleet` to enforce, warn and audit on Restricted. Label `outpost` to enforce Baseline and to warn and audit on Restricted. Pin all of these modes to `v1.35` and keep the existing `project` labels.

Then the following must hold. The `shuttle` Pod gets the `probe` response from `http://probe`. The `probe` process runs as user ID 1000. The `scout` process runs as user ID 1000, `/scratch/state` contains `ready`, and a write to `/` fails. A privileged Pod is rejected by Pod Security Admission in all three namespaces. A plain Pod is admitted in `outpost` and rejected in `starfleet` and `dock`. Do not change `shuttle`, `drifter`, the Service or the ConfigMap.

## Verify The Result

The grader checks the stated fields and runs bounded commands and server-side dry runs. Wait for both rollouts before you submit, and repeat your own checks. Inspect actual results rather than relying on a sample transcript.
