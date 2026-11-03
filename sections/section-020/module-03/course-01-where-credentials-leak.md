---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Where Credentials Leak

Teams often protect the Secret and forget the copies. A password is pasted into a ConfigMap during a test, written as a literal environment variable in a Deployment, baked into an image, or recorded by a tool. An attacker reads the weakest copy, not the strongest. This part finds the copies in a running cluster and then replaces the weakest one with a Secret.

## A ConfigMap is not a Secret

A ConfigMap stores non-secret settings as plain text. It has no special handling in the API server, and many roles can read it, including roles that cannot read Secrets. The playground has a ConfigMap named `legacy-settings` that holds a disposable credential. Check whether a credential sits in it without printing the value:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential
```

The command prints `1`, so the key `credential` is in the ConfigMap. Any identity with `get` on ConfigMaps in `starfleet` reads it. The value also appears in `kubectl describe configmap` and in every backup of the cluster state.

## Environment variables written in a manifest

An environment variable with a literal `value` is stored in the Pod specification. It is visible in the Deployment, in every Pod that the Deployment creates and in the output of `kubectl describe pod`. Save this as `pod-leaky.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: leaky
  namespace: starfleet
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    env:
    - name: PRACTICE_TOKEN
      value: disposable-v1
```

Apply it:

```sh
kubectl apply -f pod-leaky.yaml
```

Then look at what `describe` shows for the variable:

```sh
kubectl -n starfleet describe pod leaky | grep PRACTICE_TOKEN
```

The line shows the variable name and its value, because the value is part of the specification. When the variable uses `valueFrom.secretKeyRef`, the same command shows a reference to the Secret and its key instead of the value. A reference keeps the value out of the Pod specification, the Deployment and every tool that reads them.

## Annotations added by kubectl apply

The command `kubectl apply` stores the manifest you applied in the annotation `kubectl.kubernetes.io/last-applied-configuration`. It does this for every object, including a Secret. When your manifest used `stringData`, the annotation contains the plain text. Save this as `secret-practice-applied.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-applied
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v1
```

Apply it and count the plain text in the annotations:

```sh
kubectl apply -f secret-practice-applied.yaml
kubectl -n starfleet get secret practice-applied -o jsonpath='{.metadata.annotations}' | grep -c disposable
```

The second command prints `1`: the plain value sits in an annotation next to the base64 `data`. Anyone who can read the Secret object reads both, so the annotation adds no new reader here. It matters for tools that copy annotations, for example logging or backup tools, and for a cluster where annotations are readable without Secret access. Create the Secret with `kubectl create secret` or `kubectl apply --server-side` to avoid the annotation.

## Images, repositories and logs

A credential in an image stays in an image layer even when a later layer deletes the file. Anyone who pulls the image can extract it, and `docker history` shows commands and build arguments. A credential in a Git repository stays in the history after a commit that removes it. An application that prints its configuration, or a crash report that dumps its environment, writes the credential to a log. The fix for all three is the same: the image and repository hold no credential, and the application reads it at run time from a mounted file.

## Move the credential into a Secret

Replace the ConfigMap and the literal variable with a Secret mounted as a read-only file. The mount keeps the value out of the Pod specification and out of the environment. Save this as `secret-practice-moved.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-moved
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v1
---
apiVersion: v1
kind: Pod
metadata:
  name: moved-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: practice-moved
      defaultMode: 0400
```

Apply it and check the value inside the container, without printing it:

```sh
kubectl apply -f secret-practice-moved.yaml
kubectl -n starfleet wait --for=condition=Ready pod/moved-reader --timeout=120s
kubectl -n starfleet exec moved-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1 && echo match'
```

The last command prints `match`. After the new Pod works, delete the old copies: the ConfigMap key or the whole ConfigMap, and the Pod `leaky`. Deleting a copy does not make the credential safe again. A credential that was readable in a ConfigMap or a repository counts as exposed, so rotate it at its source.

You now know where the copies hide and how to replace one. The graded task on the next page asks you to do this for a ConfigMap. The remaining question is how to avoid having the Secret itself in the cluster or in Git.

## Common pitfalls

> [!WARNING]
> - **Treating a ConfigMap as safe because few people look at it.** Roles that cannot read Secrets can often read ConfigMaps.
> - **Writing a literal `value` for a credential.** It appears in the Deployment, every Pod and `kubectl describe`.
> - **Deleting a leaked copy and stopping there.** The old value stays exposed. Rotate it at its source.
> - **Forgetting `last-applied-configuration`.** `kubectl apply` of `stringData` stores the plain text in an annotation.
> - **Baking a credential into an image layer.** A later `RUN rm` does not remove it from the earlier layer.
