---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Summary

A credential exists wherever it was copied. A ConfigMap, a literal environment variable in a manifest, an image layer, a Git commit, a log line and the `kubectl.kubernetes.io/last-applied-configuration` annotation of a Secret applied with `stringData` can each hold the plain value. The `describe` output of a Pod shows a literal variable but only a reference for `secretKeyRef`. The fix is to read the credential from a Secret mounted as a read-only file, delete the copies and rotate a credential that was exposed.

An external secret store keeps the credential outside the cluster. The External Secrets Operator reads the store and creates a normal Kubernetes Secret, so the value is again in `etcd`. The Secrets Store CSI driver mounts the value into the Pod volume with no Secret object, and a Secret is created only when `secretObjects` asks for it. The cluster proves its identity to the store with a ServiceAccount token, so it holds no long-lived store password.

Sealed Secrets and SOPS let a repository hold encrypted values. Sealed Secrets decrypts in the cluster with a private key that must be backed up, and its scope ties a value to a namespace and a name. SOPS encrypts values in the file with a key from a key management service or an `age` key. Neither tool protects the Secret after it is applied, and neither removes an old plain commit.

The audit log records who read which object. The levels are `None`, `Metadata`, `Request` and `RequestResponse`, and the first matching rule wins. Secrets and ConfigMaps use `Metadata`, because the higher levels write values into the log. The key facts to remember are these:

- A ConfigMap and a literal variable are weaker than a Secret.
- Deleting a leaked copy does not make the credential safe; rotate it.
- Syncing creates a Secret; the CSI mount can avoid one.
- Audit Secrets at `Metadata` level only.

<!-- astrona:playground:destroy -->
