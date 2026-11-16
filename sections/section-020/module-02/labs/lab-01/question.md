---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret

Solve this question on: `terminal`

The `scout` agent in `starfleet-034-020-02-01` needs a login that nobody can change by accident. The `starfleet-034-020-02-01` namespace runs the `probe` Deployment (two replicas), the `probe` Service and the `shuttle` client Pod. The `outpost-034-020-02-01` namespace runs the `drifter` Pod. The Secret `probe-login` does not exist yet.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-01" || exit 1
node_name="astro-ats-034-lab-020-02-01-control-plane"
worker_name="astro-ats-034-lab-020-02-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the Secret `probe-login` in `starfleet-034-020-02-01` with type `kubernetes.io/basic-auth`, the key `username` with the value `scout`, the key `password` with the value `disposable-login`, and `immutable: true`.
2. Create the Pod `login-reader` in `starfleet-034-020-02-01` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `restartPolicy: Never` and `automountServiceAccountToken: false`. Its container is named `reader`. It mounts a Secret volume named `login` from `probe-login` at `/login`, read-only, with `defaultMode: 0400`.
3. Prove that a request to change the password of `probe-login` is rejected by the API server because the Secret is immutable.

## Constraints

- Do not print the credential to check it. Compare it inside the container.
- Preserve the namespaces, the existing workloads and everything the task does not name.

## How the answer is checked

The grader runs two checks. The first checks the type, data and `immutable` field of `probe-login` and sends a patch to its password, which must be rejected because the Secret is immutable. The second checks the fields of `login-reader`, that it is Ready, and compares the files under `/login` inside the container.

Hint: An immutable Secret can only be deleted and created again. Wait until the Pod is Ready before you submit.
