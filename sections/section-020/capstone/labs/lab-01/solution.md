---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Lock Down Secret Handling For One Workload Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-020" || exit 1
node_name="astro-ats-034-capstone-020-control-plane"
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect and explain

Start from what the Role allows and what holds the leaked value. Do not print any credential.

```sh
kubectl -n starfleet get role secret-reader -o yaml
kubectl -n starfleet get rolebinding reader-secrets -o wide
kubectl -n starfleet auth can-i list secrets --as=system:serviceaccount:starfleet:reader
```

The Role grants three verbs on all Secrets, and the last command prints `yes`. The repair narrows the Role to one verb on one named Secret. A rule with `resourceNames` matches requests that name the object, so `get` works and `list` does not.

## Create the Secrets

Save this as `secret-probe-credentials.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: probe-credentials
  namespace: starfleet
type: Opaque
immutable: true
stringData:
  token: disposable-v3
```

Save the pull credential as `secret-registry-pull.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-pull
  namespace: starfleet
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{"auths":{"registry.example.test":{"username":"practice","password":"disposable-pull"}}}'
```

Apply both:

```sh
kubectl apply -f secret-probe-credentials.yaml
kubectl apply -f secret-registry-pull.yaml
```

## Update the ServiceAccount and the Role

Save this as `serviceaccount-reader.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reader
  namespace: starfleet
automountServiceAccountToken: false
imagePullSecrets:
- name: registry-pull
```

Then save the narrowed Role as `role-secret-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: starfleet
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  resourceNames:
  - probe-credentials
  verbs:
  - get
```

Apply both:

```sh
kubectl apply -f serviceaccount-reader.yaml
kubectl apply -f role-secret-reader.yaml
```

## Create the Pod and remove the leak

Save this as `pod-credential-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: credential-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  serviceAccountName: reader
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
      secretName: probe-credentials
      defaultMode: 0400
```

Apply it, wait for it, and delete the ConfigMap only after the Pod works:

```sh
kubectl apply -f pod-credential-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/credential-reader --timeout=180s
kubectl -n starfleet delete configmap legacy-credentials
```

## Verify The Result

Check the file, its permissions and that no environment variable holds the value:

```sh
kubectl -n starfleet exec credential-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v3'
kubectl -n starfleet exec credential-reader -- stat -L -c %a /credentials/token
kubectl -n starfleet exec credential-reader -- sh -c 'test -z "$(env | grep disposable)"'
```

The second command prints `400`. Now check the access of the ServiceAccount. The first command prints `yes`. The other two print `no` and exit with a nonzero status, so run each on its own:

```sh
kubectl -n starfleet auth can-i get secret/probe-credentials --as=system:serviceaccount:starfleet:reader
kubectl -n starfleet auth can-i get secret/practice-token --as=system:serviceaccount:starfleet:reader
kubectl -n starfleet auth can-i list secrets --as=system:serviceaccount:starfleet:reader
```

Last, the change request and the ConfigMap lookup must both fail:

```sh
kubectl -n starfleet patch secret probe-credentials --type merge -p '{"stringData":{"token":"changed"}}'
kubectl -n starfleet get configmap legacy-credentials
```

## Common pitfalls

> [!WARNING]
> - Adding `list` or `watch` to the Role. Both return full Secret values.
> - Setting `resourceNames` on a rule that also allows `create`. A `create` request has no name, so the restriction does not apply to it.
> - Deleting the ConfigMap before the Pod is Ready.
> - Editing the RoleBinding. The task asks only for a narrower Role.


After recording your result, remove the independent lab with `astrona destroy ats-034-capstone-020`.
