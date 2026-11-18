---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A RuntimeClass With A ValidatingAdmissionPolicy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A RuntimeClass only takes effect when a Pod names it in `spec.runtimeClassName`. Nothing in Kubernetes forces a Pod to do that. Start by proving the gap with a server-side dry run, which sends the request through admission but does not store the Pod:

```sh
kubectl -n untrusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
```

The API server answers `pod/test created (server dry run)`. A Pod without any RuntimeClass is accepted in the untrusted namespace.

## Write the policy and its binding

A ValidatingAdmissionPolicy is a cluster-scoped object that holds a rule written in CEL (Common Expression Language). The API server evaluates the rule for every request that matches `matchConstraints`. A ValidatingAdmissionPolicyBinding decides where the policy applies and what happens on failure. The action `Deny` makes the API server reject the request. Here the binding selects one namespace by its automatic label `kubernetes.io/metadata.name`. Save this as `admissionpolicy-require-sandbox.yaml`:

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
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-sandbox-untrusted
spec:
  policyName: require-sandbox
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: untrusted-034-030-02-03
```

Apply it:

```sh
kubectl apply -f admissionpolicy-require-sandbox.yaml
```

Then check the result. Send three dry-run Pods: one without a class, one with the class, and one in the trusted namespace:

```sh
kubectl -n untrusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n untrusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --overrides='{"spec":{"runtimeClassName":"sandboxed"}}' --dry-run=server
kubectl -n trusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
```

The output is:

```text
The pods "test" is invalid: : ValidatingAdmissionPolicy 'require-sandbox' with binding 'require-sandbox-untrusted' denied request: Pods must set runtimeClassName sandboxed
pod/test created (server dry run)
pod/test created (server dry run)
```

The API server names the policy, the binding and the message in the denial. The sandboxed Pod passes, and the trusted namespace is not affected because the binding does not select it. The policy needs a second or two after the apply before it takes effect, so run the check again if the first request still passes.

## Recreate the existing Pod

The policy matches only `CREATE` requests. The old `job-runner` Pod still shows `Running`, because admission never checks objects that already exist. Delete it and create it again with the class. Save this as `pod-job-runner.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: job-runner
  namespace: untrusted-034-030-02-03
  labels:
    app: job-runner
spec:
  runtimeClassName: sandboxed
  containers:
  - name: runner
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep infinity
```

Apply it after you delete the old Pod:

```sh
kubectl -n untrusted-034-030-02-03 delete pod job-runner
kubectl apply -f pod-job-runner.yaml
kubectl -n untrusted-034-030-02-03 wait --for=condition=Ready pod/job-runner --timeout=180s
```

Then check the result:

```sh
kubectl -n untrusted-034-030-02-03 get pod job-runner -o jsonpath='{.spec.runtimeClassName}{"\n"}'
```

The output is `sandboxed`. The new Pod passed the policy and runs with the class.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-02-03`.

## Common pitfalls

> [!WARNING]
> A policy without a binding does nothing. Check that `kubectl get validatingadmissionpolicybinding` lists the binding and that it names the right policy.
>
> Without `has(object.spec.runtimeClassName)`, the expression reads a field that is missing. With `failurePolicy: Fail`, the request then fails with an evaluation error instead of the clear message.
>
> The policy does not touch running Pods. A Pod created before the policy keeps running until you delete and recreate it.
