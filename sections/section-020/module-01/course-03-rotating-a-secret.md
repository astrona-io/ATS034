---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotating A Secret

Credentials must change: a person leaves, a value leaks, a policy sets a lifetime. Rotation means replacing the value that the application uses. In Kubernetes, updating the Secret object is only the first step. Whether a running container sees the new value depends on how the Pod consumes the Secret, and the old credential still works at the system that issued it until someone revokes it. This part changes a Secret and watches both delivery paths.

## What an update changes

When you change a Secret, the API server stores the new value. Two components then react differently:

- The **environment variable** was set when the container started. Nothing changes it afterwards. The container keeps the old value until it is restarted, which means the Pod is deleted and recreated, or the container is restarted by the kubelet after a crash.
- The **Secret volume** is refreshed by the kubelet. It checks the Pods on its node on a regular sync period (one minute by default) and also uses a cache for Secrets, so the new value reaches the files after a delay. The application then has to read the file again. An application that reads the file once at start will not notice.

A mount with `subPath` and a Secret marked `immutable: true` never change. An immutable Secret rejects every change to `data`. You delete it and create a new one, usually with a new name, and change the Pod template to point at the new name. That change makes a Deployment roll out new Pods.

## Rotate and watch

Start a Pod that consumes `practice-token` both ways. Save this as `pod-rotation-reader.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rotation-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    env:
    - name: PRACTICE_TOKEN
      valueFrom:
        secretKeyRef:
          name: practice-token
          key: token
    volumeMounts:
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: practice-token
```

Apply it:

```sh
kubectl apply -f pod-rotation-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/rotation-reader --timeout=120s
```

Now rotate the value. Save this as `secret-practice-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-token
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v2
```

Apply it:

```sh
kubectl apply -f secret-practice-token.yaml
```

The command prints `secret/practice-token configured`. Then check what the running container sees through the environment variable:

```sh
kubectl -n starfleet exec rotation-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old'
```

The command prints `old`, now and every time you run it. The environment variable never changes in a running container. Check the file:

```sh
kubectl -n starfleet exec rotation-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo new || echo old'
```

Right after the apply, this command usually prints `old`. Run it again every ten seconds or so. After the kubelet syncs, which can take a minute or longer, it prints `new`. The file changed without a restart, because the kubelet swapped the `..data` link to a new directory.

## Make the environment variable follow

To load the new value into the environment variable, the container must start again. For a bare Pod, delete it and apply the Pod file again:

```sh
kubectl -n starfleet delete pod rotation-reader --wait=true
kubectl apply -f pod-rotation-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/rotation-reader --timeout=120s
kubectl -n starfleet exec rotation-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo new || echo old'
```

The last command now prints `new`. For a Deployment you do not delete Pods by hand. The command `kubectl -n <namespace> rollout restart deployment/<name>` replaces the Pods one at a time, so the service stays available. The new Pods read the current Secret when they start.

## Rotation is more than an update

Changing the Secret object does not change the system that accepts the credential. A rotation has four steps in order:

1. Create the new credential at its source, for example the database or the API provider.
2. Update the Secret object.
3. Make every consumer load it: wait for the volume refresh, or restart the Pods that use environment variables.
4. Revoke the old credential at its source.

If you revoke before every consumer has loaded the new value, those consumers fail. If you never revoke, a leaked old value stays valid. Applications that can hold two valid credentials during the switch, or that re-read the file, make this easy.

You can now rotate a Secret and prove which delivery path followed. The Secret itself, though, still sits in `etcd` in the form that anyone can reverse. The next question is how to protect it there.

## Common pitfalls

> [!WARNING]
> - **Expecting an environment variable to update.** It changes only when the container restarts.
> - **Checking the file once and concluding the update failed.** The kubelet refreshes mounted files on its own schedule. Wait and check again.
> - **Revoking the old credential first.** Consumers that still hold it fail until they load the new one.
> - **Forgetting to revoke the old credential.** Updating the Secret does not invalidate the old value at its source.
