---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Guided Practice: Create An Immutable Basic-Auth Secret

This guide repeats the steps of the module on your playground cluster. Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-020-02" || exit 1
node_name="astro-ats-034-playground-020-02-control-plane"
worker_name="astro-ats-034-playground-020-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The playground has the `probe` Deployment, the `probe` Service and two client Pods. No typed Secret exists yet. Inspect the Secrets before you change anything:

```sh
kubectl -n starfleet get secrets
kubectl get nodes -o wide
```

Create a Secret of type `kubernetes.io/basic-auth` named `probe-login` with the keys `username` and `password`, mark it immutable, and read it from a Pod named `login-reader` through a read-only volume at `/login`.

Save this as `secret-probe-login.yaml`:

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

Wait for the Pod and compare the values inside the container, so the credential is never printed:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/login-reader --timeout=180s
kubectl -n starfleet exec login-reader -- sh -c 'test "$(cat /login/username)" = scout && test "$(cat /login/password)" = disposable-login'
```

Then try to change the password. This request must fail with an error about an immutable field, so run it on its own:

```sh
kubectl -n starfleet patch secret probe-login --type merge -p '{"stringData":{"password":"changed"}}'
```

To use a different password you delete the Secret, create a new one and restart the Pod.

## Common pitfalls

> [!WARNING]
> - Confirm the private context before a change.
> - Do not change the existing `probe` workloads to hide a mistake in the new Secret.
> - A failed patch is the expected result here, not an error to fix.
