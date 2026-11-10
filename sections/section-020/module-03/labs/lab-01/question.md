---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Credential From A ConfigMap Into A Secret

Solve this question on: `terminal`

The `starfleet-034-020-03-01` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The ConfigMap `legacy-settings` in `starfleet-034-020-03-01` holds the key `credential` with the disposable value `disposable-v1` and the key `greeting`. Anyone who can read ConfigMaps can read that credential. It must leave the ConfigMap and live in a Secret that a Pod reads as a file.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-03-01" || exit 1
node_name="astro-ats-034-lab-020-03-01-control-plane"
worker_name="astro-ats-034-lab-020-03-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the Secret `migrated-credentials` in `starfleet-034-020-03-01` with type `Opaque` and the key `token` with the value `disposable-v1`.
2. Create the Pod `migrated-reader` in `starfleet-034-020-03-01` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `restartPolicy: Never` and `automountServiceAccountToken: false`. Its container is named `reader`. It mounts a Secret volume named `credentials` from `migrated-credentials` at `/credentials`, read-only, with `defaultMode: 0400`. It has no environment variable that holds the credential.
3. Delete the ConfigMap `legacy-settings`.

## Constraints

- Do not print the credential to check it. Compare it inside the container.
- Preserve the namespaces, the existing workloads and everything the task does not name.

## How the answer is checked

The grader runs three checks: the type and data of `migrated-credentials`; the fields of `migrated-reader`, that it is Ready, that `/credentials/token` holds the credential and that no environment variable does; and that `legacy-settings` no longer exists.

Hint: Create the Secret and the Pod before you delete the ConfigMap, so the value is never lost.
