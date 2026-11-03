---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Encrypting Secrets For Git

Many teams keep every cluster manifest in a Git repository and let a tool apply it, a practice called GitOps. A plain Secret manifest cannot go there, because base64 is not protection and Git keeps its history. There are two ways to put a Secret in a repository: encrypt the value inside the file, or keep only a reference. This part covers the encryption tools Sealed Secrets and SOPS, how they work and what they leave exposed. It has no commands, because both tools need software outside the playground.

## Sealed Secrets

Sealed Secrets has a controller in the cluster and a command-line tool named `kubeseal`. At install time the controller creates a key pair. Its private key never leaves the cluster. The public key is available to anyone who may seal a value. The command `kubeseal` reads a Secret manifest, encrypts each value with the public key and writes a `SealedSecret`, a custom resource that holds only ciphertext. You commit the `SealedSecret` to Git and apply it. The controller decrypts it with the private key and creates the matching Kubernetes Secret.

The ciphertext is bound to a scope. The default scope, `strict`, ties the value to the namespace and the name of the Secret, so someone who copies the encrypted value into another namespace gets a result that cannot be decrypted. The `namespace-wide` scope allows any name in the namespace, and the `cluster-wide` scope allows any name and namespace. A wider scope is easier to move and easier to abuse.

The controller renews its key every 30 days by default, but it keeps the old keys so it can decrypt old objects. If the cluster is lost and the private keys were not backed up, every `SealedSecret` in Git becomes unreadable. Back up the key and protect the backup like a root password.

## SOPS

SOPS (Secrets OPerationS) is a command-line tool that encrypts the values in a YAML or JSON file and leaves the keys readable. A diff in Git still shows which field changed. SOPS does not need a controller in the cluster. It encrypts a data key with a master key held by a key management service (KMS) such as AWS KMS, Google Cloud KMS or Azure Key Vault, or with an `age` or PGP key. People and automation decrypt a file only if they may use that master key.

The cluster side needs a tool that decrypts at apply time. Flux can decrypt SOPS files natively, and Argo CD can use a plugin. The tool needs access to the master key, so that access becomes the credential to protect. The result is a normal Kubernetes Secret in the cluster, which is then subject to RBAC and encryption at rest.

## Compare the options

The two tools solve the same problem in different ways:

| Question | Sealed Secrets | SOPS |
| --- | --- | --- |
| Who decrypts? | The controller in the cluster | The GitOps tool, with the master key |
| Where is the key? | In the cluster | In a key management service, or an `age` key |
| What does Git show? | A custom resource with ciphertext | The original file, with encrypted values |
| Can a person decrypt locally? | No, only the cluster can | Yes, if they may use the master key |

A reference-only approach, as in the External Secrets Operator, keeps no ciphertext in Git at all, only the name of the remote entry. Choose it when an organisation already runs a store with its own audit trail.

## What encryption in Git does not protect

Encrypting a manifest protects the repository. It does not protect the cluster. After the controller or the GitOps tool applies the object, the result is a normal Secret in `etcd`, with the same exposure as any other. A person who can read Secrets in the namespace reads the value. A person who can create Pods in the namespace mounts it. Encryption at rest, RBAC and a short life for the credential all still apply.

A second limit is history. If a plain value was ever committed, encrypting the file later does not remove the old commit. Rotate the credential at its source, because a repository clone may hold the old value. Scanning tools such as `gitleaks` can search a repository and its history for credentials before the problem reaches production.

You now know how to keep a Secret in Git without exposing it. The last question is how to see who actually read the Secrets in the cluster, and the next part answers it with the audit log.

## Common pitfalls

> [!WARNING]
> - **Committing a base64 Secret to Git.** Base64 is an encoding, and the history keeps the value forever.
> - **Using the `cluster-wide` scope by default.** Use `strict` unless you have a reason.
> - **Losing the Sealed Secrets private key.** Back it up, or the encrypted files cannot be restored.
> - **Encrypting a file but leaving the old plain commit.** Rotate the credential. The history still holds it.
> - **Believing the applied Secret is protected by the file encryption.** In the cluster it is an ordinary Secret.
