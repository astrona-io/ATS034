---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Guided Practice: Move A Credential From A ConfigMap Into A Secret

This guide repeats the steps of the module on your playground cluster. Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-020-03" || exit 1
node_name="astro-ats-034-playground-020-03-control-plane"
worker_name="astro-ats-034-playground-020-03-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The playground has the ConfigMap `legacy-settings`, which stores a disposable credential in the key `credential`. Check that the key exists without printing its value, and list the Pods:

```sh
kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential
kubectl -n starfleet get pods -o wide
```

Create a Secret with the same value and a Pod that reads it as a read-only file. Use a Secret, not a ConfigMap, so that Secret-specific controls apply to the value.

Save this as `secret-migrated-credentials.yaml`:

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

## Verify The Result

Wait for the Pod, compare the value inside the container and delete the ConfigMap:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/migrated-reader --timeout=180s
kubectl -n starfleet exec migrated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1'
kubectl -n starfleet delete configmap legacy-settings
```

Check that no environment variable holds the credential, then check that the ConfigMap is gone. The last command must fail with a `NotFound` error, so run it on its own:

```sh
kubectl -n starfleet exec migrated-reader -- sh -c 'test -z "$(env | grep disposable)"'
kubectl -n starfleet get configmap legacy-settings
```

## Common pitfalls

> [!WARNING]
> - Confirm the private context before a change.
> - Create and check the replacement before you delete the original.
> - Do not change the existing `probe` workloads to hide a mistake in the new Pod.
