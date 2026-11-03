---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Secret Types And How To Create Them

Most Secrets in a cluster are created by hand with a copied manifest, and a mistake in the keys shows up only when an application fails to start. Kubernetes reduces that risk with Secret types. The `type` field tells the API server what the Secret is for, and for several types the API server refuses to store the object when a required key is missing. This part lists the types, shows the validation at work and compares the ways to create a Secret.

## The built-in types

A Secret has a `type` field. When you leave it out, the type is `Opaque`, which means the API server accepts any keys. The other types are fixed names that start with `kubernetes.io/` or `bootstrap.kubernetes.io/`:

| Type | Required keys | Used for |
| --- | --- | --- |
| `Opaque` | none | Any application value |
| `kubernetes.io/basic-auth` | `username` or `password` | A user name and password |
| `kubernetes.io/ssh-auth` | `ssh-privatekey` | A Secure Shell (SSH) private key |
| `kubernetes.io/tls` | `tls.crt` and `tls.key` | A certificate and its private key, for example for an Ingress |
| `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Credentials for a container image registry |
| `kubernetes.io/service-account-token` | an annotation, not a key | A legacy long-lived ServiceAccount token |
| `bootstrap.kubernetes.io/token` | `token-id` and `token-secret` | A token that lets a new node join the cluster |

The type does not encrypt anything. It is a label with rules: the API server checks the required keys when you create or update the object, and other components look for a type. An Ingress controller expects a `kubernetes.io/tls` Secret, and the kubelet expects a `kubernetes.io/dockerconfigjson` Secret when it pulls an image. The type of an existing Secret cannot be changed. To change it, you delete the Secret and create it again.

## Let the API server validate the keys

The validation is easiest to understand when it fails. Save this as `secret-bad-login.yaml`. It declares the type `kubernetes.io/basic-auth` but holds only a key named `token`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bad-login
  namespace: starfleet
type: kubernetes.io/basic-auth
stringData:
  token: disposable-v1
```

Apply it:

```sh
kubectl apply -f secret-bad-login.yaml
```

The API server rejects the request with an error that says a required key is missing, and it stores nothing. If the same manifest used the type `Opaque`, the API server would accept it. This is why a typed Secret catches mistakes early.

## Three ways to create a Secret

Writing YAML is one way. The `kubectl create secret` command is the second way, and it builds the object for you. The subcommand `generic` creates an `Opaque` Secret. The values come from `--from-literal=key=value` or from a file with `--from-file=key=path`:

```sh
kubectl -n starfleet create secret generic practice-config --from-literal=mode=training
kubectl -n starfleet get secret practice-config -o jsonpath='{.type}{"\n"}'
```

The second command prints `Opaque`, the default type. The subcommands `tls` and `docker-registry` create the typed Secrets for certificates and registries, and they check their own inputs. For example, `kubectl create secret tls NAME --cert=tls.crt --key=tls.key` reads two files and stores them under the keys `tls.crt` and `tls.key`.

Each way has a cost. A value typed with `--from-literal` is saved in the shell history and appears in the process list while the command runs. A value read with `--from-file` stays out of both, but the file must be stored safely and deleted afterwards. A YAML manifest holds the value in a file that someone can commit to a repository by mistake. For real credentials, prefer `--from-file` or a secret store, and never put a real value in a file that a repository tracks.

The third way is the field `stringData`. It accepts plain text on write, and the API server stores it in `data` as base64. The `kubectl get` output then shows only `data`.

You can see the stored form of the Secret you just created:

```sh
kubectl -n starfleet get secret practice-config -o jsonpath='{.data.mode}{"\n"}'
kubectl -n starfleet get secret practice-config -o jsonpath='{.data.mode}' | base64 -d
```

The first command prints the base64 text for `training`, and the second decodes it. Both commands show the value in your terminal, so use this only for a disposable value.

## Which type to use

The rule is to use the most specific type that exists. A TLS key and certificate belong in a `kubernetes.io/tls` Secret, because an Ingress controller and the validation both depend on the type. A registry credential belongs in a `kubernetes.io/dockerconfigjson` Secret. A password for an application, with a user name, can use `kubernetes.io/basic-auth`, and anything else uses `Opaque`.

You now know the types and how the API server checks them. A registry credential has one more detail, because the kubelet, not the application, reads it. The next part follows that credential into a Pod and ServiceAccount.

## Common pitfalls

> [!WARNING]
> - **Using `Opaque` for everything.** The API server then cannot catch a missing key, and tools that look for a type do not find the Secret.
> - **Trying to change the type of a Secret.** The type is fixed after creation. Delete the Secret and create it again.
> - **Typing a real value with `--from-literal`.** The value stays in the shell history. Use `--from-file` or a secret store.
> - **Assuming the type protects the value.** A type only validates keys. Protection comes from RBAC and encryption at rest.
