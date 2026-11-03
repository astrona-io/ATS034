---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Create An Immutable Basic-Auth Secret Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-01" || exit 1
node_name="astro-ats-034-lab-020-02-01-control-plane"
worker_name="astro-ats-034-lab-020-02-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect and explain

Start with the objects that exist. The Secret type decides which keys the API server requires, so read the type rules before you write the manifest.

```sh
kubectl -n starfleet get secrets
kubectl get nodes -o wide
```

The type `kubernetes.io/basic-auth` requires at least one of the keys `username` and `password`. The field `immutable` sits at the top level of the Secret, next to `type`, not inside `data`.

Save this as `secret-probe-login.yaml`, which holds the Secret and the Pod in one file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: probe-login
  namespace: starfleet
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
  namespace: starfleet
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

## Verify The Result

Wait for the Pod, then compare the values inside the container. These commands print nothing when the values match, and fail when they differ.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/login-reader --timeout=180s
kubectl -n starfleet exec login-reader -- sh -c 'test "$(cat /login/username)" = scout && test "$(cat /login/password)" = disposable-login'
```

Now try to change the password. This command must fail, so run it on its own, not in a shell sequence that stops on the first error:

```sh
kubectl -n starfleet patch secret probe-login --type merge -p '{"stringData":{"password":"changed"}}'
```

The API server rejects the request with a `Forbidden` error that says the field is immutable. The only way to change an immutable Secret is to delete it and create a new one.

## Common pitfalls

> [!WARNING]
> - Writing `immutable: true` under `data`. It is a top-level field of the Secret.
> - Using the type `kubernetes.io/basic-auth` without `username` or `password`. The API server rejects the Secret.
> - Testing the change on a Secret that is not immutable yet. Apply the final Secret first, then try the change.


After recording your result, remove the independent lab with `astrona destroy ats-034-lab-020-02-01`.
