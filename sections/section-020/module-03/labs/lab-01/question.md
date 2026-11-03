---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Credential From A ConfigMap Into A Secret

Replace a credential stored in a ConfigMap with a Secret mounted as a read-only file, and remove the ConfigMap.

## Starting state

The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The ConfigMap `legacy-settings` in `starfleet` holds the key `credential` with the disposable value `disposable-v1` and the key `greeting`. Anyone who can read ConfigMaps can read that credential. The required result has not been configured.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-03-01" || exit 1
node_name="astro-ats-034-lab-020-03-01-control-plane"
worker_name="astro-ats-034-lab-020-03-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

The credential must leave the ConfigMap and live in a Secret that a Pod reads as a file.

1. Create the Secret `migrated-credentials` in `starfleet` with type `Opaque` and the key `token` with the value `disposable-v1`.
2. Create the Pod `migrated-reader` in `starfleet` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `restartPolicy: Never` and `automountServiceAccountToken: false`. Its container is named `reader`. It mounts a Secret volume named `credentials` from `migrated-credentials` at `/credentials`, read-only, with `defaultMode: 0400`. It has no environment variable that holds the credential.
3. Delete the ConfigMap `legacy-settings`.

Do not print the credential to check it. Compare it inside the container.

## Verify The Result

The grader checks the required object fields and live observations. Wait until the Pod is Ready before you submit, and repeat your own checks first. Preserve the namespaces, the existing workloads and everything the task does not name.
