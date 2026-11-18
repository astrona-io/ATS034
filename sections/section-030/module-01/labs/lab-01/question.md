---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Limit A Tenant User To One Namespace With RBAC

Allow about 10 minutes for the tasks.

The user `alice` works for tenant A only. Today she can change objects in every namespace and read every Secret, so a mistake or a stolen credential reaches tenant B as well.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespaces `tenant-a-034-030-01-01` and `tenant-b-034-030-01-01` exist, and each one holds a Secret named `api-key`. The ClusterRoleBinding `alice-edit` binds the built-in ClusterRole `edit` to the user `alice` in every namespace. You act as the cluster administrator.

## Tasks

1. In `tenant-a-034-030-01-01`, create a Role named `tenant-editor` that allows the verbs `get`, `list`, `watch`, `create`, `update` and `delete` on Pods, Services and ConfigMaps (core API group) and on Deployments (`apps` API group). Do not allow Secrets.
2. In the same namespace, create a RoleBinding named `tenant-editor` that binds this Role to the user `alice`.
3. Remove every cluster-wide permission of `alice`, so she has no access in `tenant-b-034-030-01-01` and none on cluster-scoped objects such as nodes and namespaces.

## Check your work

`kubectl auth can-i` asks the API server whether a request would be allowed. The `--as` flag sends the question as another user:

```sh
kubectl auth can-i create deployments -n tenant-a-034-030-01-01 --as=alice
kubectl auth can-i get secrets -n tenant-a-034-030-01-01 --as=alice
kubectl auth can-i create deployments -n tenant-b-034-030-01-01 --as=alice
kubectl auth can-i list nodes --as=alice
```

The first command must print `yes`. The other three must print `no`.
