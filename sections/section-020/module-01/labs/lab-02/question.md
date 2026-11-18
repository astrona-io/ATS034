---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumers

Allow about 12 minutes for the tasks.

The practice token in `starfleet-034-020-01-02` must be rotated. The `file-reader` pod must pick up the new value without a restart, and the `env-reader` pod must be recreated so that it sees the new value too.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-020-01-02` holds the Secret `practice-token`. Its key `token` holds the disposable value `disposable-v1`. Two pods read it:

- `file-reader` mounts the Secret as a volume at `/credentials`.
- `env-reader` reads the key `token` into the environment variable `PRACTICE_TOKEN`.

The ConfigMap `rotation-start` records the UID of both starting pods. A UID is the unique ID that Kubernetes gives each object, so a recreated pod has a new UID. Do not change this ConfigMap.

## Tasks

1. Change the key `token` of the Secret `practice-token` from `disposable-v1` to `disposable-v2`. Keep the Secret name and type.
2. Keep the original `file-reader` pod running. Do not delete or recreate it. Its file `/credentials/token` must show the new value.
3. Recreate the pod `env-reader` with the same spec, so that `PRACTICE_TOKEN` still comes from the key `token` of `practice-token` and holds the new value.
4. Do not print the credential. Compare it inside the container.

## Check your work

Each command compares the value inside the container and prints only `new` or `old`:

```sh
kubectl -n starfleet-034-020-01-02 exec file-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo new || echo old'
kubectl -n starfleet-034-020-01-02 exec env-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old'
```

Both commands must print `new`. The file can take a minute or two to change after the update, so run the first command again if it still prints `old`.
