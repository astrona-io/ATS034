---
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret

Allow about 8 minutes for the tasks.

The `scout` agent in `starfleet-034-020-02-02` needs a login that nobody can change by accident. Create it as an immutable Secret and give it to a reader pod as read-only files.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-020-02-02` runs the `shuttle` client pod. The Secret `probe-login` and the pod `login-reader` do not exist yet.

## Tasks

1. Create the Secret `probe-login` in `starfleet-034-020-02-02` with the type `kubernetes.io/basic-auth`, the key `username` with the value `scout`, the key `password` with the value `disposable-login`, and `immutable: true`.
2. Create the pod `login-reader` in `starfleet-034-020-02-02` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `restartPolicy: Never` and `automountServiceAccountToken: false`. Its container is named `reader`. It mounts a Secret volume named `login` from `probe-login` at `/login`, read-only, with `defaultMode: 0400`.
3. Do not print the credential. Compare it inside the container.

## Check your work

The first command compares the files inside the container and prints only `match` or `different`. The second command tries to change the password:

```sh
kubectl -n starfleet-034-020-02-02 exec login-reader -- sh -c 'test "$(cat /login/username)" = scout && test "$(cat /login/password)" = disposable-login && echo match || echo different'
kubectl -n starfleet-034-020-02-02 patch secret probe-login --type merge -p '{"stringData":{"password":"changed"}}'
```

The first command must print `match`. The second command must fail with an error that says the field is immutable.
