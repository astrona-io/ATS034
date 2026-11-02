---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# What A Secret Is And Who Can Read It

An application needs credentials: a database password, an API token, a private key. Writing them into the image or a ConfigMap puts them in places that many people can read. Kubernetes has a separate object for them, the Secret. A Secret keeps credentials out of images and manifests, and it lets you control access to them. This part shows what a Secret really contains, why its encoding offers no secrecy, and which control does protect it.

## The structure of a Secret

A **Secret** is a Kubernetes object that holds a small amount of sensitive data, up to 1 MiB, in a map of keys and values. The data lives in `data` as base64 text. The field `stringData` is a write-only convenience: you send plain text, and the API server converts it to base64 and stores it in `data`. The `type` field names the shape of the content:

- `Opaque` is the default type for arbitrary key-value data.
- `kubernetes.io/tls` holds a certificate and a private key in the keys `tls.crt` and `tls.key`.
- `kubernetes.io/dockerconfigjson` holds the credentials for a container image registry.
- `kubernetes.io/basic-auth` and `kubernetes.io/ssh-auth` hold a user name and password, or an SSH private key.
- `kubernetes.io/service-account-token` holds a legacy long-lived ServiceAccount token.

For the types other than `Opaque`, the API server checks that the required keys exist.

## Base64 is not encryption

**Base64** is a way to write bytes as text. It has no key, so anyone can reverse it. The playground has a Secret called `practice-token` in the `starfleet` namespace. Read its stored value:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}'
```

The command prints a short string of letters and digits that ends with `=` characters. That is the stored form. Decode it on your machine:

```sh
kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}' | base64 --decode
```

The output is the plain text `disposable-v1`. No key was needed. Anyone who can run `get` on the Secret can decode it, and so can anyone who can read the `etcd` database, a backup of it, or the manifest in a Git repository. This is why a Secret that you commit to Git is a leaked credential, even though it looks encoded.

Create a second Secret from the command line, to see both input forms. Save this as `secret-api-key.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-key
  namespace: starfleet
type: Opaque
stringData:
  key: disposable-api-key
```

Apply it:

```sh
kubectl apply -f secret-api-key.yaml
```

Then check the result:

```sh
kubectl -n starfleet get secret api-key -o yaml
```

The output has a `data` field with the key `key` and a base64 value, and it has no `stringData` field. The API server converted the plain text on write and never stores `stringData`. The command `kubectl describe secret api-key` goes the other way: it shows the key names and the size of each value in bytes, but not the values.

## What protects a Secret

If the encoding does not protect the value, something else must. In Kubernetes, three controls do:

- **RBAC** (role-based access control) decides which identities may `get`, `list` and `watch` Secrets. This is the first control. A `list` or `watch` on Secrets returns the values of all Secrets in scope, so it grants as much as `get`.
- **Encryption at rest** makes the data unreadable to someone who reads the `etcd` files or a backup. It does not stop a user that the API server authorizes.
- **Pod access** decides who can read a Secret through a container. Anyone who can create a Pod in a namespace can mount any Secret of that namespace, and anyone who can `exec` into that Pod can read the value.

Ask the API server what an identity may do with `kubectl auth can-i`. The `default` ServiceAccount of the `starfleet` namespace is the identity that Pods use when they do not choose another:

```sh
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:default
kubectl auth can-i list secrets -n starfleet --as=system:serviceaccount:starfleet:default
```

Both commands print `no`. A ServiceAccount has no permissions until a Role binds some to it, so a compromised application in a normal Pod cannot read other Secrets through the API. It can still read the Secrets that its own Pod mounts. Your own user in the playground is a cluster administrator, so the same check without `--as` prints `yes`.

You now know that a Secret is protected by access control and encryption at rest, not by its encoding. The next question is how a Secret gets from the API into the container that needs it, and what a container can do with it once it is there.

## Common pitfalls

> [!WARNING]
> - **Calling base64 "encrypted".** It is an encoding with no key. Decoding takes one command.
> - **Committing a Secret manifest to Git.** The values are readable by everyone with access to the repository.
> - **Granting `list` or `watch` on Secrets.** Both return the values of every Secret in the scope, so they are as sensitive as `get`.
> - **Reading `describe` output as proof of safety.** `kubectl describe secret` hides the values, but `kubectl get secret -o yaml` shows them.
