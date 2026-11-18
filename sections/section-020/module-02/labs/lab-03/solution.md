---
exam_objectives:
- Manage Kubernetes secrets
---
# Limit Secret Access To One Named Secret With RBAC Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

RBAC (role-based access control) is the part of the API server that decides which identity may use which verb on which resource. A Role lists rules for one namespace, and a RoleBinding gives those rules to a user, a group or a ServiceAccount. The field `resourceNames` limits a rule to objects with those names.

## Write the Role

`resourceNames` works for verbs that name one object, such as `get`, `update` and `delete`. It cannot limit `list` or `watch`, because a list request does not name an object. So the Role allows only `get`.

Save this as `role-secret-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: starfleet-034-020-02-03
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  resourceNames:
  - probe-credentials
  verbs:
  - get
```

Apply it:

```sh
kubectl apply -f role-secret-reader.yaml
```

## Bind it to the ServiceAccount

Save this as `rolebinding-auditor-secret-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: auditor-secret-reader
  namespace: starfleet-034-020-02-03
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader
subjects:
- kind: ServiceAccount
  name: auditor
  namespace: starfleet-034-020-02-03
```

Apply it:

```sh
kubectl apply -f rolebinding-auditor-secret-reader.yaml
```

## Check the access matrix

The command `kubectl auth can-i` asks the API server whether an identity may do one action. With `--as`, your admin user asks on behalf of the ServiceAccount. The user name of a ServiceAccount is `system:serviceaccount:<namespace>:<name>`. A small loop checks every verb in one go:

```sh
AUDITOR=system:serviceaccount:starfleet-034-020-02-03:auditor
for check in "get secret/probe-credentials" "get secret/other-credentials" "list secrets" "watch secrets" "create secrets" "update secret/probe-credentials" "delete secret/probe-credentials"; do
  printf '%-36s %s\n' "$check" "$(kubectl auth can-i $check -n starfleet-034-020-02-03 --as "$AUDITOR")"
done
```

Only the first line must end with `yes`. Every other line must end with `no`. Then make one real request of each kind as the ServiceAccount:

```sh
kubectl -n starfleet-034-020-02-03 get secret probe-credentials --as "$AUDITOR" -o name
kubectl -n starfleet-034-020-02-03 get secret other-credentials --as "$AUDITOR" -o name
```

The first command prints `secret/probe-credentials`. The second fails with an error that the user is `forbidden` to get the Secret `other-credentials`.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-02-03`.

## Common pitfalls

> [!WARNING]
> Adding `list` to a rule with `resourceNames` does not limit the list to that name. A `kubectl get secrets` sends a list request, which carries no name, so the rule does not match it and the request is denied. Some users then remove `resourceNames` to make it work, which opens every Secret.
>
> The `apiGroups` value for Secrets is the empty string `""`, the core group. Writing `v1` makes the rule match nothing.
