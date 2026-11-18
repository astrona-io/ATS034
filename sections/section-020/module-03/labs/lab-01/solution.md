---
exam_objectives:
- Manage Kubernetes secrets
---
# Move A Leaked Credential Into A Secret Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A literal `value` of an environment variable is part of the pod template. Anyone who can read the Deployment, any of its pods, or the output of `kubectl describe` reads it. A `secretKeyRef` stores only the name of the Secret and the key, and the kubelet, the agent on the node, reads the value when it starts the container.

## Create the Secret

Create the Secret with `kubectl create secret`. Unlike `kubectl apply` of a manifest with `stringData`, this command does not store the plain value in the annotation `kubectl.kubernetes.io/last-applied-configuration`:

```sh
kubectl -n starfleet-034-020-03-01 create secret generic scout-credentials --from-literal=token=disposable-scout
```

## Change the Deployment

Replace the literal `value` with a reference to the Secret. Changing the pod template makes the Deployment controller start a new pod and stop the old one.

Save this as `deployment-scout.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
  namespace: starfleet-034-020-03-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      automountServiceAccountToken: false
      containers:
      - name: scout
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 86400
        env:
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: scout-credentials
              key: token
```

Apply it:

```sh
kubectl apply -f deployment-scout.yaml
```

Then check the result. Wait for the rollout, read the `env` list of the template, and compare the value inside the new container:

```sh
kubectl -n starfleet-034-020-03-01 rollout status deployment/scout --timeout=180s
kubectl -n starfleet-034-020-03-01 get deployment scout -o jsonpath='{.spec.template.spec.containers[0].env}{"\n"}'
kubectl -n starfleet-034-020-03-01 exec deployment/scout -- sh -c 'test "$API_TOKEN" = disposable-scout && echo match || echo different'
```

The `env` list must show only the `secretKeyRef` to `scout-credentials` and `token`, and the last command must print `match`.

## Remove the old copy

Delete the ConfigMap only after the new pod works, so the application is never without its token:

```sh
kubectl -n starfleet-034-020-03-01 delete configmap legacy-settings
```

In a real cluster the token now counts as exposed, because it was readable in a ConfigMap and in the Deployment. Rotate it at the service that issued it, then update the Secret.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> If you change the Deployment with `kubectl edit` or `kubectl set env`, the old literal value can stay in the annotation `kubectl.kubernetes.io/last-applied-configuration` of the Deployment. Apply the full manifest again, or remove the annotation, so no copy of the token is left in the object.
>
> `kubectl set env deployment/scout --from=secret/scout-credentials` creates a variable for every key of the Secret, named after the key (`TOKEN`), and keeps the old `API_TOKEN`. Use an explicit `secretKeyRef` for one named variable.
