---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Summary

A namespace is a scope for names and policy. It separates object names, RBAC, quotas and Pod Security profiles. It does not separate nodes, the kernel, the network, or cluster-scoped objects such as nodes, PersistentVolumes and ClusterRoles. Soft multi-tenancy, for tenants that trust each other, can rely on namespaces and policy. Hard multi-tenancy, for hostile code, needs a stronger boundary such as a sandboxed runtime, dedicated nodes or separate clusters.

RBAC limits what a user can do. A Role lists verbs on resources in one namespace, and a RoleBinding attaches it to a user, group or ServiceAccount. Permissions only add up, so there is no deny rule. A ClusterRoleBinding applies in every namespace, while a RoleBinding limits a ClusterRole to one. `kubectl auth can-i` with `--as` checks the result.

A ResourceQuota limits the total of a namespace, for objects and for compute. A LimitRange sets minimum, maximum and default values for single containers, and it supplies the requests and limits that a compute quota requires. Both act at creation time. A quota failure appears as a `FailedCreate` event on the ReplicaSet, not on the Deployment.

A NetworkPolicy selects Pods and lists allowed traffic. A Pod that no policy selects accepts all traffic. An empty `podSelector` with a policy type and no rules is a default-deny policy, and rules only add allowances. The CNI plugin must enforce policies, a blocked connection times out, and rules name the Pod port, not the Service port. A default-deny egress policy also blocks DNS. Setting `automountServiceAccountToken: false` on the Pod or the ServiceAccount removes the API token from Pods that do not call the API.

Sandboxed runtimes add a kernel boundary. gVisor runs the container against a user-space kernel (`runsc`), and Kata Containers runs each Pod in a lightweight virtual machine. A RuntimeClass maps a name to a runtime handler, and a Pod selects it with `runtimeClassName`. The administrator must install the handler on the nodes. A RuntimeClass can add node selectors, tolerations and fixed overhead. A Pod with a class whose handler is missing is accepted and then stays in `ContainerCreating`. The key facts to remember are these:

- Namespaces separate names and policy, not the kernel or the network.
- Policies add allowances only; default deny comes from selecting Pods and listing no rules.
- Quota and LimitRange act at creation; read the ReplicaSet events for failures.
- A RuntimeClass names a handler. It does not install one.

<!-- astrona:playground:destroy -->
