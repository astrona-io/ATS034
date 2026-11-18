---
exam_objectives:
- Manage Kubernetes secrets
---
# Limit Secret Access To One Named Secret With RBAC

Allow about 10 minutes for the tasks.

The `auditor` ServiceAccount in `starfleet-034-020-02-03` must read the probe credential and nothing else. It must not list Secrets, because a list returns the values of every Secret in the namespace.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-020-02-03` holds the ServiceAccount `auditor` and the two Secrets `probe-credentials` and `other-credentials`. The ServiceAccount has no access to Secrets yet.

## Tasks

1. Create the Role `secret-reader` in `starfleet-034-020-02-03`. It must allow only the verb `get` on the Secret `probe-credentials`.
2. Bind the Role to the ServiceAccount `auditor` with a RoleBinding in the same namespace.
3. The ServiceAccount `auditor` must not be able to get `other-credentials`, and must not list, watch, create, update or delete Secrets.

## Check your work

```sh
AUDITOR=system:serviceaccount:starfleet-034-020-02-03:auditor
kubectl auth can-i get secret/probe-credentials -n starfleet-034-020-02-03 --as "$AUDITOR"
kubectl auth can-i get secret/other-credentials -n starfleet-034-020-02-03 --as "$AUDITOR"
kubectl auth can-i list secrets -n starfleet-034-020-02-03 --as "$AUDITOR"
```

The first command must print `yes`. The other two must print `no`.
