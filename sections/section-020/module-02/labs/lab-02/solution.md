---
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The type of a Secret tells the API server which keys it must check. The type `kubernetes.io/basic-auth` requires at least one of the keys `username` and `password`. The field `immutable` sits at the top level of the Secret, next to `type`, not inside `data`. Once it is `true`, the API server rejects every change to `data` and `stringData`, and the kubelet stops watching the Secret for changes.

Save this as `secret-probe-login.yaml`. It holds the Secret and the pod in one file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: probe-login
  namespace: starfleet-034-020-02-02
type: kubernetes.io/basic-auth
immutable: true
stringData:
  username: scout
  password: disposable-login
---
apiVersion: v1
kind: Pod
metadata:
  name: login-reader
  namespace: starfleet-034-020-02-02
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    volumeMounts:
    - name: login
      mountPath: /login
      readOnly: true
  volumes:
  - name: login
    secret:
      secretName: probe-login
      defaultMode: 0400
```

Apply it:

```sh
kubectl apply -f secret-probe-login.yaml
```

Then check the result. Wait for the pod, then compare the values inside the container:

```sh
kubectl -n starfleet-034-020-02-02 wait --for=condition=Ready pod/login-reader --timeout=180s
kubectl -n starfleet-034-020-02-02 exec login-reader -- sh -c 'test "$(cat /login/username)" = scout && test "$(cat /login/password)" = disposable-login && echo match || echo different'
```

The second command must print `match`. Now try to change the password. This command must fail, so run it on its own, not in a shell sequence that stops on the first error:

```sh
kubectl -n starfleet-034-020-02-02 patch secret probe-login --type merge -p '{"stringData":{"password":"changed"}}'
```

The API server rejects the request with a `Forbidden` error that says the field is immutable. The only way to change an immutable Secret is to delete it and create it again, usually with a new name that the pod spec then points at.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-02-02`.

## Common pitfalls

> [!WARNING]
> Writing `immutable: true` under `data` makes it a key of the Secret, not the field. Keep it at the top level, next to `type`.
>
> The type `kubernetes.io/basic-auth` without `username` or `password` is rejected by the API server. Check the required keys of a type before you write the manifest.
