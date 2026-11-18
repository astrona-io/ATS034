---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumers Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Rotation means you replace a credential with a new value. The API server stores the new value in the Secret at once, but a pod sees it only through the path it uses. The kubelet, the agent on each node, refreshes a mounted Secret volume on its next sync, so the same running pod sees the new file after a short delay. An environment variable is copied once, when the container starts, so only a new pod sees the new value.

Start with the Secret. A `stringData` field takes the plain value, and the API server writes it into `data` as base64 text.

Save this as `secret-practice-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-token
  namespace: starfleet-034-020-01-02
type: Opaque
stringData:
  token: disposable-v2
```

Apply it:

```sh
kubectl apply -f secret-practice-token.yaml
```

Then check the result. Compare the file inside `file-reader` and run the command again until it prints `new`:

```sh
kubectl -n starfleet-034-020-01-02 exec file-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo new || echo old'
```

The command prints `old` at first. It prints `new` once the kubelet has synced the volume, which took a little over a minute in a test run. Do not delete `file-reader` to speed this up: the task asks for the same pod, and the grader compares its UID with the UID in `rotation-start`.

The `env-reader` pod still holds the old value, because its environment was set when the container started. Delete the pod and create it again with the same spec.

```sh
kubectl -n starfleet-034-020-01-02 delete pod env-reader --wait=true
```

Save this as `pod-env-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: starfleet-034-020-01-02
  labels:
    app: env-reader
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "86400"]
    env:
    - name: PRACTICE_TOKEN
      valueFrom:
        secretKeyRef:
          name: practice-token
          key: token
```

Apply it:

```sh
kubectl apply -f pod-env-reader.yaml
```

Then check the result. Wait for the new pod and compare the environment variable:

```sh
kubectl -n starfleet-034-020-01-02 wait --for=condition=Ready pod/env-reader --timeout=180s
kubectl -n starfleet-034-020-01-02 exec env-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old'
```

The command must print `new`. The new pod has a new UID, and its container read the Secret when it started, after the rotation. In a real cluster a Deployment does the same job: `kubectl rollout restart deployment <name>` replaces its pods so that they read the new value.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-01-02`.

## Common pitfalls

> [!WARNING]
> A volume mounted with `subPath` never receives updates. If a file stays `old` for many minutes, check the pod spec for `subPath` before you wait longer.
>
> Restarting the process inside a container does not change its environment variables. Only a new container, started from the pod spec, reads the Secret again.
