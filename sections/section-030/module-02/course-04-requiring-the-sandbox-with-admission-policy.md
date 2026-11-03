---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Requiring The Sandbox With Admission Policy

A `RuntimeClass` is opt-in. A Pod that leaves out `runtimeClassName` runs on the default handler, and a tenant who can create Pods can choose not to use the sandbox. The control must therefore live in admission, where the API server can reject the request. This part writes a policy that allows only sandboxed Pods in selected namespaces and tests it with allowed and denied requests.

## Admission policy with CEL

A **ValidatingAdmissionPolicy** is a built-in admission rule that the API server evaluates with the Common Expression Language (CEL). It needs no webhook server. The policy holds the match rules and the expressions. A **ValidatingAdmissionPolicyBinding** applies the policy to a set of namespaces and chooses the action. An expression that returns `false` rejects the request with the policy message when the action is `Deny`.

The policy below matches Pod creation and requires the class name `sandboxed`. Save this as `policy-require-sandbox.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-sandbox
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["pods"]
  validations:
  - expression: "has(object.spec.runtimeClassName) && object.spec.runtimeClassName == 'sandboxed'"
    message: "Pods must set runtimeClassName sandboxed"
```

Apply it:

```sh
kubectl apply -f policy-require-sandbox.yaml
```

A policy does nothing until a binding applies it. Save this as `binding-require-sandbox.yaml`. It selects the namespace by its automatic name label:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-sandbox-tenant-b
spec:
  policyName: require-sandbox
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tenant-b
```

Apply it:

```sh
kubectl apply -f binding-require-sandbox.yaml
```

The API server needs a few seconds to start enforcing a new binding. If the next test is accepted, wait a moment and repeat it.

## Test a denied and an allowed request

A server-side dry run runs all admission steps and stores nothing. First send a Pod without a class:

```sh
kubectl -n tenant-b run plain --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server -- sleep 60
```

The command fails. The message names the policy, the binding and the text `Pods must set runtimeClassName sandboxed`. The component that rejected the request is the API server admission step, not the scheduler or the kubelet. Now send a Pod with the class by saving this as `pod-policy-allowed.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: policy-allowed
  namespace: tenant-b
spec:
  runtimeClassName: sandboxed
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "60"]
```

Test it without storing it:

```sh
kubectl apply -f pod-policy-allowed.yaml --dry-run=server
```

The request is accepted. A Pod in another namespace is not affected, because the binding selects only `tenant-b`.

## Limits of this control

The expression checks one field at creation time. It does not prove that the node has a real sandbox handler, and it does not stop a user who may edit the policy or the binding. Tenants must never have RBAC rights on admission objects. Pod Security Admission (PSA) can also exempt a runtime class by name in its configuration, so check that tenant classes are not on that exemption list. Pods created before the binding exist stay as they are, so audit them with `kubectl get pods -o jsonpath` on `runtimeClassName`.

Use `validationActions: ["Audit", "Warn"]` first on a live cluster. Audit records the violation in the audit log, and Warn returns a warning to the user. Switch to `Deny` after the existing workloads comply.

You can now force every new Pod in a namespace to use the sandbox class, and prove it with a denied and an allowed request. The control covers new Pods, so a complete tenant boundary still combines it with the node and network controls.

## Common pitfalls

> [!WARNING]
> - **Creating the policy without a binding.** An unbound policy is never evaluated.
> - **Testing right after the binding.** Enforcement can lag by a few seconds.
> - **Using `has()` too late.** Without `has(object.spec.runtimeClassName)`, a Pod with no class can make the expression fail with an error instead of `false`.
> - **Forgetting existing Pods.** The policy checks creation only.
> - **Trusting the expression to prove a sandbox.** It checks the requested class name only.
