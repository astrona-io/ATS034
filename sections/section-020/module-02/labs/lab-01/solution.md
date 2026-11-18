---
exam_objectives:
- Manage Kubernetes secrets
---
# Give A ServiceAccount An Image Pull Secret Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

An image pull Secret is a Secret of type `kubernetes.io/dockerconfigjson`. Its one key, `.dockerconfigjson`, holds a JSON (JavaScript Object Notation) document with a login per registry server. The kubelet, the agent on each node, reads this Secret when it pulls an image for a pod that lists it in `imagePullSecrets`.

## Create the Secret

The command `kubectl create secret docker-registry` builds the JSON document for you. With `--dry-run=client -o yaml`, kubectl only writes the object, so you can keep it in a file and apply it like any other configuration:

```sh
kubectl -n starfleet-034-020-02-01 create secret docker-registry registry-pull \
  --docker-server=registry.example.test \
  --docker-username=practice \
  --docker-password=disposable-pull \
  --dry-run=client -o yaml > secret-registry-pull.yaml
```

Apply it:

```sh
kubectl apply -f secret-registry-pull.yaml
```

Then check the result. The first command must print `kubernetes.io/dockerconfigjson`. The second command decodes the JSON document and prints only the server names, not the password; it must print `registry.example.test`:

```sh
kubectl -n starfleet-034-020-02-01 get secret registry-pull -o jsonpath='{.type}{"\n"}'
kubectl -n starfleet-034-020-02-01 get secret registry-pull -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | grep -o '"registry.example.test"'
```

## Attach it to the ServiceAccount

A ServiceAccount is the identity a pod runs as. When it lists `imagePullSecrets`, the ServiceAccount admission plugin in the API server copies that list into every new pod that uses the ServiceAccount and has no list of its own.

Save this as `serviceaccount-puller.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: puller
  namespace: starfleet-034-020-02-01
imagePullSecrets:
- name: registry-pull
```

Apply it:

```sh
kubectl apply -f serviceaccount-puller.yaml
```

## Start a pod as the ServiceAccount

The pod sets only `serviceAccountName`. It does not list the Secret itself.

Save this as `pod-pull-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pull-check
  namespace: starfleet-034-020-02-01
spec:
  serviceAccountName: puller
  restartPolicy: Never
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-pull-check.yaml
```

Then check the result. The pod must become Ready, and its stored specification must now contain `registry-pull`, which the API server added:

```sh
kubectl -n starfleet-034-020-02-01 wait --for=condition=Ready pod/pull-check --timeout=180s
kubectl -n starfleet-034-020-02-01 get pod pull-check -o jsonpath='{.spec.imagePullSecrets[*].name}{"\n"}'
```

The pod starts even though `registry.example.test` does not exist, because its image comes from Docker Hub and is already on the node. The kubelet only uses the login when it pulls from the matching server.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-02-01`.

## Common pitfalls

> [!WARNING]
> The API server copies `imagePullSecrets` from the ServiceAccount only when it creates the pod. A pod that already ran before you changed the ServiceAccount keeps its old list. Delete the pod and create it again.
>
> A Secret of type `Opaque` with a key called `.dockerconfigjson` is not an image pull Secret. The kubelet needs the type `kubernetes.io/dockerconfigjson`.
