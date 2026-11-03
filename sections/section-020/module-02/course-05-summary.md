---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Summary

A Secret has a type, and the type decides which keys the API server requires. `Opaque` accepts anything. The types `kubernetes.io/basic-auth`, `kubernetes.io/tls`, `kubernetes.io/ssh-auth` and `kubernetes.io/dockerconfigjson` check their keys when the object is created. The type of an existing Secret cannot change. A type validates keys and does not protect values. The commands `kubectl create secret generic`, `tls` and `docker-registry` build the objects, and a value typed with `--from-literal` stays in the shell history.

The kubelet pulls images with the registry credential in a `kubernetes.io/dockerconfigjson` Secret that a Pod or its ServiceAccount names in `imagePullSecrets`. The Secret must be in the namespace of the Pod. Since Kubernetes 1.24 a Pod receives a bound ServiceAccount token that expires and is tied to the Pod, while a token stored in a `kubernetes.io/service-account-token` Secret never expires. `kubectl create token` issues a short-lived token, and `automountServiceAccountToken: false` removes the token from Pods that do not need it.

The field `immutable: true` locks the data of a Secret and cannot be undone. The API server rejects every change, and the kubelet stops watching the Secret. A rotation creates a new Secret with a new name and changes the Pod template, so a Deployment rolls out new Pods. The replacement exists before the original is deleted.

A Role with `resourceNames` limits `get` to named Secrets. `list` and `watch` return values, `create` ignores names, and permission to create Pods reads every Secret of the namespace. `kubectl auth can-i` with `--as` tests an identity, and `--list` shows everything it may do. The key facts to remember are these:

- A Secret type validates keys and does not encrypt.
- Bound tokens expire; legacy token Secrets do not.
- Immutable Secrets are replaced, not edited.
- Name the Secret in the Role, grant `get` only and review Pod creation.

<!-- astrona:playground:destroy -->
