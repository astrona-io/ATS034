---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Limit A Tenant User To One Namespace With RBAC Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

RBAC (role-based access control) is the part of the API server that decides whether a user may send a request. A Role lists allowed verbs on resources in one namespace. A RoleBinding gives the rules of a Role to users, groups or ServiceAccounts in that same namespace. A ClusterRoleBinding gives the rules of a ClusterRole in every namespace, which is the problem here.

Start by asking the API server what `alice` can do today:

```sh
kubectl auth can-i create deployments -n tenant-b-034-030-01-01 --as=alice
kubectl auth can-i get secrets -n tenant-a-034-030-01-01 --as=alice
```

Both commands print `yes`. The `edit` ClusterRole includes Secrets, and the ClusterRoleBinding `alice-edit` applies it in every namespace. Find every binding that names `alice`:

```sh
kubectl get clusterrolebindings -o wide | grep alice
```

The output shows one line for `alice-edit`, with `ClusterRole/edit` as its role and `alice` in the users column.

Now write the namespaced access. The Role names only the four resource types the task lists, so Secrets stay out. Save this as `rbac-tenant-editor.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-editor
  namespace: tenant-a-034-030-01-01
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-editor
  namespace: tenant-a-034-030-01-01
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: tenant-editor
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```sh
kubectl apply -f rbac-tenant-editor.yaml
```

RBAC has no deny rule. Permissions only add up, so the new Role takes nothing away while `alice-edit` exists. Delete the cluster-wide binding:

```sh
kubectl delete clusterrolebinding alice-edit
```

Then check the result:

```sh
kubectl auth can-i create deployments -n tenant-a-034-030-01-01 --as=alice
kubectl auth can-i get secrets -n tenant-a-034-030-01-01 --as=alice
kubectl auth can-i create deployments -n tenant-b-034-030-01-01 --as=alice
kubectl auth can-i list nodes --as=alice
```

The first command prints `yes` and the other three print `no`. Before the last `no`, kubectl prints `Warning: resource 'nodes' is not namespace scoped`, because a node belongs to no namespace. A real request shows the same result. A server-side dry run sends the request through authorization and admission but does not store the object:

```sh
kubectl -n tenant-a-034-030-01-01 create deployment web --image=docker.io/library/busybox:1.37.0 --dry-run=server --as=alice
kubectl -n tenant-b-034-030-01-01 get pods --as=alice
```

The first command prints `deployment.apps/web created (server dry run)`. The second fails with `Error from server (Forbidden)`, and the message names the user `alice`, the resource `pods` and the namespace `tenant-b-034-030-01-01`.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-01-01`.

## Common pitfalls

> [!WARNING]
> Adding a Role does not remove a wider binding. RBAC only adds permissions, so look for every ClusterRoleBinding that names the user and remove the ones that are too wide.
>
> `kubectl auth can-i` answers for one verb and one resource. Check the denied cases too (Secrets, the other namespace, nodes), not only the allowed one.
