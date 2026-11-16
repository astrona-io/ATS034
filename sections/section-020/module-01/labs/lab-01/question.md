---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumer

Solve this question on: `terminal`

The Secret `practice-token` in `starfleet-034-020-01-01` holds the key `token` with the disposable value `disposable-v1`. The credential must be rotated, and a new reader must see the new value both as an environment variable and as a file. The namespace also runs two healthy `probe` replicas, an internal Service and the `shuttle` client Pod.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-01" || exit 1
node_name="astro-ats-034-lab-020-01-01-control-plane"
worker_name="astro-ats-034-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 7 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Update the key `token` of the Secret `practice-token` from `disposable-v1` to `disposable-v2`.
2. Create the Pod `rotated-reader` in `starfleet-034-020-01-01` with `restartPolicy: Never`, one container named `reader`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep 3600"`. Set the environment variable `PRACTICE_TOKEN` from the key `token` of `practice-token`, and mount a Secret volume named `secret` from `practice-token` at `/credentials`, read-only.
3. Check inside the container, without printing the credential, that `$PRACTICE_TOKEN` and `/credentials/token` both equal the new value.

## Constraints

- Do not print the credential. Compare it inside the container.
- Do not change the `probe` Deployment, the Service or the client Pods.

## How the answer is checked

The grader runs two checks. The first checks that `practice-token` holds `disposable-v2`. The second checks the fields, volume and mount of `rotated-reader`, that it is Ready, and runs a command in it that compares both delivery paths with the new value.

Hint: An environment variable is read once, when the container starts. A Pod created after the rotation sees the new value; an older Pod would need to be recreated.
