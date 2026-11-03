---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Image Pull Secrets And ServiceAccount Tokens

Two credentials in a cluster are not read by the application. The first is the registry credential that the kubelet uses to pull a container image. The second is the token that a Pod uses to call the Kubernetes API server. Both are stored or issued in ways that changed over several releases, and the exam expects you to know which way is safe. This part builds a registry credential, attaches it to a ServiceAccount and compares the token types.

## The registry credential

A private container registry refuses to send an image to a client that does not log in. The kubelet is the agent on each node that starts the containers of the Pods on that node, and it pulls the image before the container starts. It finds the login in a Secret of type `kubernetes.io/dockerconfigjson`, which holds a JSON document under the key `.dockerconfigjson`. The document lists registry addresses with a user name and a password.

The command `kubectl create secret docker-registry` builds that document for you. The registry address below is a name that does not exist, so nothing is pulled; the exercise only creates the objects. Start with the Secret:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet create secret docker-registry practice-pull --docker-server=registry.example.test --docker-username=practice --docker-password=disposable-pull
kubectl -n starfleet get secret practice-pull -o jsonpath='{.type}{"\n"}'
```

The second command prints `kubernetes.io/dockerconfigjson`. A Secret of this type is read by the kubelet only when a Pod or its ServiceAccount names it in `imagePullSecrets`.

## Attach the credential to a ServiceAccount

A ServiceAccount is the identity that a Pod uses when it talks to the API server. It also carries a list of `imagePullSecrets`. Every Pod that uses the ServiceAccount receives that list, so you do not repeat it in every Pod specification. Create a ServiceAccount and attach the Secret:

```sh
kubectl -n starfleet create serviceaccount puller
kubectl -n starfleet patch serviceaccount puller -p '{"imagePullSecrets":[{"name":"practice-pull"}]}'
kubectl -n starfleet get serviceaccount puller -o jsonpath='{.imagePullSecrets[0].name}{"\n"}'
```

The last command prints `practice-pull`. A Pod can also set `imagePullSecrets` directly in its own specification, and the Pod value is used together with the ServiceAccount value. The Secret must be in the same namespace as the Pod. A Pod cannot use a pull Secret from another namespace.

The credential still has a weakness. Any user who can read Secrets in the namespace can decode the registry password. Use a registry account that has read-only access to the images, and rotate its password like any other credential.

## Two kinds of ServiceAccount token

A ServiceAccount token is a signed JSON Web Token (JWT), a text value that proves an identity to the API server. Older clusters created a long-lived token for each ServiceAccount and stored it in a Secret of type `kubernetes.io/service-account-token`. Such a token never expires. It stays valid until someone deletes the Secret or the ServiceAccount, so a copy in a backup or a log stays dangerous.

Since Kubernetes 1.24 the control plane no longer creates those Secrets. A Pod receives a bound token instead. The kubelet requests it through the TokenRequest API and mounts it in a projected volume. A bound token expires, names its audience, and is tied to the Pod, so the API server rejects it after the Pod is deleted. The kubelet refreshes the file before it expires.

You can request a short-lived token yourself. This command stores the token nowhere and only prints a confirmation, so the token is never shown:

```sh
kubectl -n starfleet create token puller --duration=10m > /dev/null && echo created
```

The command prints `created`. In normal use you would pass the token to a client, and it stops working after ten minutes.

You can still create a legacy token Secret on purpose. Save this as `secret-puller-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: puller-token
  namespace: starfleet
  annotations:
    kubernetes.io/service-account.name: puller
type: kubernetes.io/service-account-token
```

Apply it:

```sh
kubectl apply -f secret-puller-token.yaml
```

Then check that the token controller filled in the value. The command counts the occurrences of the key name and prints a number, not the token:

```sh
kubectl -n starfleet get secret puller-token -o jsonpath='{.data}' | grep -c token
```

The token controller in the control plane signs a token and writes it into the Secret, so the command prints `1`. This Secret now holds a token that never expires. Delete it when you finish with the exercise:

```sh
kubectl -n starfleet delete secret puller-token
```

## Which one to choose

Use bound tokens for Pods and `kubectl create token` for a short task. Create a legacy token Secret only for a system outside the cluster that cannot request tokens, and treat it as a password with no expiry date. Set `automountServiceAccountToken: false` on Pods that do not call the API server, so no token is mounted at all.

You now know how the kubelet gets a registry login and why bound tokens are safer than stored ones. Both controls protect a credential after it exists. The next part makes a Secret impossible to change.

## Common pitfalls

> [!WARNING]
> - **Creating the pull Secret in the wrong namespace.** A Pod can only use pull Secrets from its own namespace.
> - **Using a registry account with write access.** A leaked pull credential then lets an attacker push images.
> - **Creating a legacy token Secret for convenience.** It never expires. Prefer `kubectl create token` or a bound token.
> - **Mounting a token into Pods that never call the API server.** Set `automountServiceAccountToken: false`.
