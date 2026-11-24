---
exam_objectives:
- Manage Kubernetes secrets
---
# Summary

A Secret is a Kubernetes object that holds small sensitive values. Its `data` field uses base64, which is an encoding with no key, so it hides nothing. The field `stringData` accepts plain text on write and is stored as base64 in `data`. The protection comes from other controls. RBAC decides who may `get`, `list` and `watch` Secrets, and `list` and `watch` return values as `get` does. Pod access decides who reads a Secret through a container, because anyone who can create a Pod in a namespace can mount its Secrets. `kubectl auth can-i` shows what an identity may do.

A container receives a Secret as an environment variable or as a volume. An environment variable is set once, when the container starts, and child processes, crash dumps and `/proc/<pid>/environ` can expose it. A Secret volume is written by the kubelet onto a `tmpfs`, with file permissions from `defaultMode`, and a symbolic link swap replaces the files when the Secret changes. A `subPath` mount and an immutable Secret never change. A Pod can reference only Secrets from its own namespace.

Rotation has four steps. Create the new credential at its source, update the Secret, make every consumer load it, and revoke the old credential. A mounted file follows the Secret after the kubelet syncs, which can take a minute or longer, while an environment variable changes only when the container restarts. A Deployment restarts its Pods with `kubectl rollout restart`.

Encryption at rest protects Secrets in `etcd`. An `EncryptionConfiguration` file lists providers for the resource `secrets`. The first provider encrypts writes, and all providers are tried in order for reads, so `identity` must come last. The providers are `aescbc`, `aesgcm`, `secretbox` and `kms`, and `kms` keeps the key outside the control plane. Secrets stored before the change need a rewrite. Reading `etcd` with `etcdctl` shows the prefix `k8s:enc:` when encryption works.

A key rotation uses the same rule of writes and reads. The new key goes first in the list of `aescbc` keys and the old key stays below it. The kube-apiserver reads the file only when it starts, and a change to the file does not change the static pod manifest, so stopping the kube-apiserver container with `crictl stop` makes the kubelet start a new one with the new keys. After a rewrite of every Secret, a count of the prefixes `k8s:enc:aescbc:v1:key1:` and `k8s:enc:aescbc:v1:key2:` in `etcd` proves that no value needs the old key. Only then can the old key leave the file. A kube-apiserver without the old key cannot decrypt the Secrets that still use it: reads fail with `no matching key was found for the provided AES transformer`, and the readiness check stays failed. The key facts to remember are these:

- Base64 is encoding. RBAC and encryption at rest are the protection.
- Environment variables update only on restart; Secret volumes update after a delay.
- The first provider in the list encrypts; `identity` first means no encryption.
- In a key rotation the new key goes first, and the old key leaves only after every Secret is rewritten.
- Encryption at rest does not hide a Secret from a user the API server authorizes.

<!-- astrona:playground:destroy -->
