---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret

Create a typed, immutable Secret and mount it read-only so the API server rejects every change to its data.

## Starting state

The `starfleet` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost` namespace runs the `drifter` Pod. The Secret `probe-login` does not exist yet. The required result has not been configured.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-01" || exit 1
node_name="astro-ats-034-lab-020-02-01-control-plane"
worker_name="astro-ats-034-lab-020-02-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

The `scout` agent in `starfleet` needs a login that nobody can change by accident.

1. Create the Secret `probe-login` in `starfleet` with type `kubernetes.io/basic-auth`, the key `username` with the value `scout`, the key `password` with the value `disposable-login`, and `immutable: true`.
2. Create the Pod `login-reader` in `starfleet` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `restartPolicy: Never` and `automountServiceAccountToken: false`. Its container is named `reader`. It mounts a Secret volume named `login` from `probe-login` at `/login`, read-only, with `defaultMode: 0400`.
3. A request to change the password of `probe-login` must be rejected by the API server because the Secret is immutable.

Do not print the credential to check it. Compare it inside the container.

## Verify The Result

The grader checks the required object fields and live observations. Wait until the Pod is Ready before you submit, and repeat your own checks first. Preserve the namespaces, the existing workloads and everything the task does not name.
