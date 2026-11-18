---
exam_objectives:
- Manage Kubernetes secrets
---
# Deliver A Secret As An Environment Variable And A File

Allow about 10 minutes for the tasks.

A new `token-reader` pod in `starfleet-034-020-01-01` must receive the practice token in two ways: as an environment variable and as a file that only its owner can read.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-020-01-01` holds the Secret `practice-token` of type `Opaque`. Its key `token` holds the disposable value `disposable-v1`. The namespace also runs the pod `shuttle`. No pod reads the Secret yet.

## Tasks

1. Create the pod `token-reader` in `starfleet-034-020-01-01` with `restartPolicy: Never` and one container named `reader`. Use the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`.
2. Set the environment variable `PRACTICE_TOKEN` in the container from the key `token` of the Secret `practice-token`.
3. Mount the Secret `practice-token` as a volume at `/credentials`, read-only. The file `/credentials/token` must have the mode `0400`, so only its owner can read it.
4. Do not print the credential. Compare it inside the container.

## Check your work

Each command compares the value inside the container and prints only `match` or `different`. The last command prints the file mode:

```sh
kubectl -n starfleet-034-020-01-01 exec token-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v1 && echo match || echo different'
kubectl -n starfleet-034-020-01-01 exec token-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1 && echo match || echo different'
kubectl -n starfleet-034-020-01-01 exec token-reader -- stat -L -c %a /credentials/token
```

The first two commands must print `match`. The last command must print `400`.
