---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Least-Privilege Access To Secrets

A Secret is only as private as the list of identities that can read it. The most common mistake is a Role that allows `get` on all Secrets in a namespace, because it is the quickest way to make an application work. Role-Based Access Control (RBAC) can name the exact Secret an identity may read. This part writes such a Role, tests it and lists the other paths that reach a Secret.

## Name the Secret in the Role

A Role is a Kubernetes object that lists permissions inside one namespace. Each rule names API groups, resources, verbs and, optionally, `resourceNames`. A rule with `resourceNames` applies only to objects with those names. A RoleBinding connects the Role to a subject, here a ServiceAccount. Create a ServiceAccount, a Role that allows `get` on the Secret `practice-token` and a RoleBinding:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet create serviceaccount auditor
kubectl -n starfleet create role secret-getter --verb=get --resource=secrets --resource-name=practice-token
kubectl -n starfleet create rolebinding auditor-secret-getter --role=secret-getter --serviceaccount=starfleet:auditor
```

Each command creates one object. The API server evaluates RBAC on every request, and the Role grants nothing until the RoleBinding exists.

## Test with kubectl auth can-i

The command `kubectl auth can-i` asks the API server whether an identity may perform a request. The flag `--as` sends the request as another identity. A ServiceAccount identity has the form `system:serviceaccount:<namespace>:<name>`. Run four checks:

```sh
kubectl -n starfleet auth can-i get secret/practice-token --as=system:serviceaccount:starfleet:auditor
kubectl -n starfleet auth can-i get secret/practice-pull --as=system:serviceaccount:starfleet:auditor
kubectl -n starfleet auth can-i list secrets --as=system:serviceaccount:starfleet:auditor
kubectl -n starfleet auth can-i create pods --as=system:serviceaccount:starfleet:auditor
```

The first command prints `yes`. The other three print `no`: the Role does not name `practice-pull`, it does not allow `list`, and it does not allow creating Pods. The `no` answers exit with a nonzero status, so a script that stops on errors needs to handle them.

The `practice-pull` Secret exists only if you created it in the previous exercises. If it does not exist, the command still prints `no`, because RBAC checks the rule, not the object.

## What a name restriction does not cover

The restriction is exact, and it has limits that appear on the exam:

- **`list` and `watch`.** These verbs return full objects. A rule that allows them on all Secrets exposes every value. A `resourceNames` rule limits `list` and `watch` only when the request names the object with a field selector, so grant `get` for one Secret.
- **`create`.** A create request has no object name yet, so `resourceNames` does not restrict it.
- **Pod creation.** An identity that can create a Pod in the namespace can mount any Secret of that namespace and read it from inside the container. Reading Secrets through the API and creating Pods are separate permissions, and both need review.
- **Wildcards.** A rule with `*` in `resources` or `verbs` includes Secrets. Search for them.
- **ClusterRoles.** A ClusterRole bound with a ClusterRoleBinding applies to every namespace, so it reads Secrets everywhere. Bind a ClusterRole with a RoleBinding to limit it to one namespace.

## Review who can read Secrets

To review an identity, list everything it may do in a namespace:

```sh
kubectl -n starfleet auth can-i --list --as=system:serviceaccount:starfleet:auditor
```

The output lists each resource and verb that the identity holds, including rules that apply to every authenticated user. To find which bindings exist, list them and read the subjects:

```sh
kubectl -n starfleet get rolebindings -o wide
kubectl get clusterrolebindings -o wide
```

Read the output for bindings whose Role grants Secrets and whose subject is a group such as `system:authenticated` or a ServiceAccount that does not need them.

## Reduce the exposure around the Role

A narrow Role works best with other controls. Give each application its own ServiceAccount, so a Role is not shared by unrelated workloads. Set `automountServiceAccountToken: false` on Pods that do not use the API, so a compromised container cannot call the API server with the token. Move the application to read its Secret from a mounted file and drop the API permission altogether, because the kubelet mounts the Secret and the Pod does not need the `get` verb. A Pod that only mounts a Secret needs no Role at all.

You now know how to limit reading to one Secret and how to test the limit. What remains open is the credential outside the cluster: in manifests, images and external stores that Role rules cannot reach.

## Common pitfalls

> [!WARNING]
> - **Granting `get` on all Secrets for convenience.** Name the Secret with `resourceNames`.
> - **Granting `list` or `watch` on Secrets.** Both return values. Treat them like `get`.
> - **Forgetting the Pod path.** Permission to create Pods in a namespace is permission to read its Secrets.
> - **Binding a ClusterRole with a ClusterRoleBinding.** The access then applies to every namespace.
> - **Reading `no` from `can-i` as an error.** It is the answer, and the exit status is nonzero.
