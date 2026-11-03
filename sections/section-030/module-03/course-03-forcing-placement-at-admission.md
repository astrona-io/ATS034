---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Forcing Placement At Admission

A dedicated node does not help if a tenant can create a Pod without the selector. The tenant could land on shared nodes, and a different tenant could use the selector to land on the dedicated node unless a taint stops it. The fix is to make the placement fields mandatory at admission. This part compares two built-in admission plugins and a policy-based option, and tests the policy option on the playground.

## Two built-in plugins

The **PodNodeSelector** plugin reads the annotation `scheduler.alpha.kubernetes.io/node-selector` on a namespace. It merges that selector into every Pod created there, and it rejects a Pod whose own selector conflicts. The **PodTolerationRestriction** plugin reads the annotations `scheduler.alpha.kubernetes.io/defaultTolerations` and `scheduler.alpha.kubernetes.io/tolerationsWhitelist`. It adds default tolerations and rejects tolerations outside the whitelist.

Together they bind a namespace to a node group: the namespace selector forces the Pod to the tenant's nodes, and the whitelist stops the tenant from tolerating other taints. Both plugins are off by default. An administrator turns them on with the flag `--enable-admission-plugins` of the API server, which on a kubeadm control plane means editing the static Pod manifest, and the API server restarts.

## A policy-based option

When you cannot change API server flags, use a `ValidatingAdmissionPolicy`. It does not merge anything. It rejects Pods that lack the selector. Save this as `policy-require-tenant-node.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-tenant-node
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["pods"]
  validations:
  - expression: "has(object.spec.nodeSelector) && 'tenant' in object.spec.nodeSelector && object.spec.nodeSelector['tenant'] == 'tenant-c'"
    message: "Pods in tenant-c must select tenant=tenant-c"
```

Apply it:

```sh
kubectl apply -f policy-require-tenant-node.yaml
```

Save the binding as `binding-require-tenant-node.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-tenant-node-tenant-c
spec:
  policyName: require-tenant-node
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tenant-c
```

Apply it:

```sh
kubectl apply -f binding-require-tenant-node.yaml
```

Wait a few seconds for enforcement. Then send a Pod without the selector, using a server-side dry run:

```sh
kubectl -n tenant-c run no-selector --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -- sleep 60
```

The API server rejects it with the policy message. A Pod that sets `nodeSelector` to `tenant: tenant-c` passes admission.

## What admission still cannot do

The expression checks fields, not the real node. If the label on the node is wrong, a Pod that passes admission lands on the wrong node. The taint is still needed to keep other tenants off the dedicated node, and a policy for each other namespace must forbid the tolerations for it. A CEL expression can compare tolerations by listing them with `object.spec.tolerations.exists(...)`.

Policy covers new Pods. Use the audit mode first and fix existing workloads before switching to deny. Also protect the policy objects with RBAC so that tenants cannot delete them.

You can now make placement mandatory with built-in plugins or with a policy. A separate node still shares some things with the rest of the cluster, so the last part decides which boundary fits which threat.

## Common pitfalls

> [!WARNING]
> - **Assuming PodNodeSelector is on.** Both plugins are off unless the administrator enables them.
> - **Enforcing the selector but not the tolerations.** A tenant can still tolerate a foreign taint.
> - **Forgetting that a CEL expression on a missing field fails.** Use `has()` before reading `nodeSelector`.
> - **Leaving policy edit rights to tenants.** They could delete the control.
