---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Node Labels You Can Trust

A node selector is only as trustworthy as the label it matches. If a compromised node can write its own labels, it can claim to be the dedicated node of a tenant and attract that tenant's Pods, together with the data they carry. This part explains how the kubelet credentials limit that attack and which label names are safe to use for isolation.

## What a kubelet may change

Each kubelet authenticates to the API server with its own credential, which identifies it as one node. The **Node authorizer** and the **NodeRestriction admission plugin** limit that credential. A kubelet can modify only its own Node object and Pods bound to its node. It cannot read Secrets that no Pod on its node uses.

NodeRestriction also limits labels. A kubelet cannot set or change labels in the prefix `node-restriction.kubernetes.io/`, and it cannot set labels in the `kubernetes.io` and `k8s.io` namespaces beyond a fixed allowed list. It can set other labels on its own Node object, such as `tenant`, so a compromised node can claim `tenant=tenant-c`.

Labels in the protected prefix can only be set by a client with the right to update nodes, such as an administrator. Use a name like `node-restriction.kubernetes.io/tenant` for isolation labels and select on it in the Pod.

## Check that the plugin is on

NodeRestriction is enabled by default in current kubeadm clusters, but it is a flag of the API server, so check it. List the admission plugins from the API server Pod:

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}'
```

The command line contains the flags. Look for `--enable-admission-plugins` and the entry `NodeRestriction`. Also look for `--authorization-mode` with `Node` and `RBAC`. If a flag is not present, the Kubernetes default plugin list applies, which includes NodeRestriction in current versions. The listing proves only the configured flags, so a missing line is not proof that the plugin is off.

## Use the protected label

An administrator labels the worker with the protected prefix. This label survives a compromised kubelet:

```sh
kubectl label node astro-ats-034-playground-030-03-worker node-restriction.kubernetes.io/tenant=tenant-c
```

Read the labels back:

```sh
kubectl get node astro-ats-034-playground-030-03-worker --show-labels
```

The output lists the new label next to the labels that the node reports about itself. A Pod can now select this label. The kubelet cannot change it, and a tenant cannot set it either, because tenants have no right to update Node objects.

## Who else can change placement

RBAC decides who may label and taint nodes. A tenant must have no `update` or `patch` on `nodes`. Test it for a tenant user:

```sh
kubectl auth can-i patch nodes --as=tenant-c-user
```

The answer must be `no`. Also remember that a tenant who creates Pods chooses the selector and tolerations. Protecting the label stops forgery of the node side, but not a tenant who removes the selector from the Pod. The next part moves that decision to admission.

You can now choose label names that a compromised kubelet cannot forge. The tenant still writes the Pod fields, so enforcement must come from the API server.

## Common pitfalls

> [!WARNING]
> - **Selecting on a plain `tenant` label.** A compromised kubelet can set it on its own Node object.
> - **Giving tenants `patch` on nodes.** They could relabel or untaint the dedicated node.
> - **Assuming the flags are always visible.** A default plugin does not appear in the flag list.
> - **Treating the label as enforcement.** It protects the node side only.
