---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Credential From A ConfigMap Into A Secret Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-03-01" || exit 1
node_name="astro-ats-034-lab-020-03-01-control-plane"
worker_name="astro-ats-034-lab-020-03-01-worker"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect and explain

A ConfigMap is for settings that are not secret. It has no special protection, and many roles can read it. Look at what the ConfigMap holds, without printing the credential:

```sh
kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential
kubectl -n starfleet get pods -o wide
```

The first command prints `1` when the key `credential` is present. Create the Secret and the Pod that reads it.

Save this as `secret-migrated-credentials.yaml`, which holds the Secret and the Pod in one file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: migrated-credentials
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v1
---
apiVersion: v1
kind: Pod
metadata:
  name: migrated-reader
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
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: migrated-credentials
      defaultMode: 0400
```

Apply it:

```sh
kubectl apply -f secret-migrated-credentials.yaml
```

Delete the ConfigMap only after the new Pod is Ready, so you know the Secret works:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/migrated-reader --timeout=180s
kubectl -n starfleet delete configmap legacy-settings
```

## Verify The Result

Compare the value inside the container and check that no environment variable holds it. The second command prints nothing and succeeds when no variable value contains the word `disposable`:

```sh
kubectl -n starfleet exec migrated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1'
kubectl -n starfleet exec migrated-reader -- sh -c 'test -z "$(env | grep disposable)"'
```

Then confirm that the ConfigMap is gone. This command must fail with a `NotFound` error, so run it on its own:

```sh
kubectl -n starfleet get configmap legacy-settings
```

## Common pitfalls

> [!WARNING]
> - Deleting the ConfigMap before the new Pod works. Create and check the replacement first.
> - Copying the credential into an environment variable. The task asks for a file.
> - Leaving the value in the ConfigMap. Anyone who can read ConfigMaps still reads it.


After recording your result, remove the independent lab with `astrona destroy ats-034-lab-020-03-01`.
