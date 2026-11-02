---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Namespaces And RBAC As A Tenant Boundary

Teams that share a cluster want to share its cost, but not each other's mistakes. One team should not read another team's Secrets, delete its Deployments or starve it of memory. Kubernetes has no object called "tenant". This part explains what a namespace does and does not separate, and builds the first layer: a namespace that one user can manage and nobody else can.

## What a namespace separates

A **namespace** is a scope for names and for policy. Two namespaces can both hold a Service called `api`. Most policy objects attach to a namespace: Roles, RoleBindings, ResourceQuotas, NetworkPolicies and the Pod Security labels. A namespace separates these things:

- Object names and the access that RBAC grants to them.
- Quotas and limits, when you create them.
- Pod Security Admission profiles, through labels.

A namespace does not separate these things:

- The node. Pods of different namespaces run on the same nodes and share the same Linux kernel per node.
- The network. By default every Pod can reach every other Pod and every Service in the cluster, in any namespace.
- Cluster-scoped objects. Nodes, PersistentVolumes, StorageClasses, ClusterRoles, CustomResourceDefinitions and the namespaces themselves have no namespace.

**Multi-tenancy** means that several tenants share one cluster. In **soft multi-tenancy** the tenants trust each other, for example teams of one company. Namespaces, RBAC, quotas and network rules are enough, because the risk is an error, not an attack. In **hard multi-tenancy** a tenant may run hostile code, for example a customer's code. Then a shared kernel is a risk, and the cluster needs sandboxed runtimes, dedicated nodes or separate clusters.

## Build the tenant namespace

Create a namespace for a tenant with a restricted Pod Security profile. Save this as `namespace-tenant-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-demo
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-tenant-demo.yaml
```

Now give the user `tenant-user` rights in this namespace only. A **Role** is a list of allowed verbs on resources inside one namespace. A **RoleBinding** attaches a Role to users, groups or ServiceAccounts in that namespace. Save this as `rbac-tenant-demo.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-editor
  namespace: tenant-demo
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
  namespace: tenant-demo
subjects:
- kind: User
  name: tenant-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: tenant-editor
  apiGroup: rbac.authorization.k8s.io
```

Apply it:

```sh
kubectl apply -f rbac-tenant-demo.yaml
```

The Role does not include Secrets. A tenant that manages Deployments does not need to read every Secret in the namespace, so leave it out unless it is required.

## Verify the boundary

Ask the API server what `tenant-user` can do. The `--as` flag makes your administrator identity send the request as another user:

```sh
kubectl auth can-i create deployments -n tenant-demo --as=tenant-user
kubectl auth can-i get secrets -n tenant-demo --as=tenant-user
kubectl auth can-i create deployments -n starfleet --as=tenant-user
kubectl auth can-i list nodes --as=tenant-user
```

The first command prints `yes`. The other three print `no`: Secrets are not in the Role, `starfleet` has no binding for this user, and nodes are cluster-scoped, so a namespaced Role can never grant them. The check follows the RBAC rule that permissions only add up. There is no deny rule, so a user has what the union of its bindings allows.

List the resource kinds that no namespace contains:

```sh
kubectl api-resources --namespaced=false
```

The output includes `nodes`, `persistentvolumes`, `storageclasses`, `clusterroles` and `namespaces`. These objects are shared by every tenant, which is why a tenant must never receive a ClusterRole that grants them.

The access layer is in place: the tenant works in its namespace and cannot see other namespaces' objects through the API. Nothing yet limits how much of the cluster its Pods can use, and nothing stops its Pods from reaching other namespaces over the network.

## Common pitfalls

> [!WARNING]
> - **Treating a namespace as a security boundary on its own.** It separates names and policy. Pods still share nodes, the kernel and, by default, the network.
> - **Binding a ClusterRole with a ClusterRoleBinding to give namespace access.** A ClusterRoleBinding applies in every namespace. Use a RoleBinding, which can also reference a ClusterRole, to limit it to one namespace.
> - **Including `secrets` in a tenant Role without need.** `get`, `list` and `watch` on Secrets expose their values.
> - **Expecting a deny rule.** RBAC has none. Remove the permission instead.
