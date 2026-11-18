---
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Leaked Credential Into A Secret

Allow about 10 minutes for the tasks.

The `scout` Deployment in `starfleet-034-020-03-01` has its API token written as a literal environment variable, and an old copy of the same token sits in the ConfigMap `legacy-settings`. Move the token into a Secret and remove both plain copies.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The Deployment `scout` runs one pod with the container `scout`. Its pod template sets the environment variable `API_TOKEN` with a literal `value`, the disposable token `disposable-scout`. The ConfigMap `legacy-settings` holds the same token in the key `credential`, and the key `greeting`.

## Tasks

1. Create the Secret `scout-credentials` in `starfleet-034-020-03-01`. Its key `token` must hold `disposable-scout`.
2. Change the Deployment `scout` so that `API_TOKEN` in the container `scout` comes from the key `token` of the Secret `scout-credentials`. The pod template must not contain the token as a literal value anywhere.
3. The rollout of `scout` must finish, and the running container must see the token in `API_TOKEN`.
4. Delete the ConfigMap `legacy-settings`.

Do not print the token to check it. Compare it inside the container.

## Check your work

```sh
kubectl -n starfleet-034-020-03-01 get deployment scout -o jsonpath='{.spec.template.spec.containers[0].env}{"\n"}'
kubectl -n starfleet-034-020-03-01 exec deployment/scout -- sh -c 'test "$API_TOKEN" = disposable-scout && echo match || echo different'
kubectl -n starfleet-034-020-03-01 get configmap legacy-settings
```

The first command must show a `secretKeyRef` and no `value`. The second must print `match`. The third must fail with `NotFound`.
