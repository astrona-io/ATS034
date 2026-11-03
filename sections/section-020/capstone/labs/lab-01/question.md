---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Lock Down Secret Handling For One Workload

Combine a typed immutable Secret, a pull credential, a read-only mounted file, a least-privilege Role and the removal of a leaked credential.

## Starting state

The `starfleet` namespace runs the `probe` Deployment, the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs `drifter`. The ServiceAccount `reader` in `starfleet` is bound by the RoleBinding `reader-secrets` to the Role `secret-reader`. That Role allows `get`, `list` and `watch` on every Secret in the namespace. The Secret `practice-token` exists. The ConfigMap `legacy-credentials` holds the disposable credential `disposable-v3` in plain text. No other Secret exists.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-020" || exit 1
node_name="astro-ats-034-capstone-020-control-plane"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

The `reader` workload must receive its credential safely and must not be able to read any other Secret. Create and repair the following.

1. Create the Secret `probe-credentials` in `starfleet` with type `Opaque`, the key `token` with the value `disposable-v3`, and `immutable: true`.
2. Create the Secret `registry-pull` in `starfleet` with type `kubernetes.io/dockerconfigjson` for the server `registry.example.test`, user `practice` and password `disposable-pull`. Add it to the `imagePullSecrets` of the ServiceAccount `reader`. Keep `automountServiceAccountToken: false` on the ServiceAccount.
3. Repair the Role `secret-reader` so that it has one rule: `get` on the Secret named `probe-credentials` and nothing else. Do not change the RoleBinding.
4. Create the Pod `credential-reader` in `starfleet` with the ServiceAccount `reader`, `automountServiceAccountToken: false`, the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"` and `restartPolicy: Never`. Its container is named `reader`. It mounts a Secret volume named `credentials` from `probe-credentials` at `/credentials`, read-only, with `defaultMode: 0400`. It has no environment variable that holds the credential.
5. Delete the ConfigMap `legacy-credentials`.

Then the following must hold. The file `/credentials/token` in the Pod has the permissions `400` and holds the credential. The ServiceAccount `reader` may `get` the Secret `probe-credentials`. It may not `get` the Secret `practice-token`, and it may not `list` Secrets. A request to change the token of `probe-credentials` is rejected because the Secret is immutable. Do not print the credentials to check them.

## Verify The Result

The grader checks the required object fields and live observations. Wait until the Pod is Ready before you submit, and repeat your own checks first. Preserve the namespaces, the existing workloads and everything the task does not name.
