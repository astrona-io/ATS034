---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A Tenant Node Selector With A ValidatingAdmissionPolicy Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A ValidatingAdmissionPolicy is an API object that holds rules written in CEL (Common Expression Language). The API server checks each matching request against the rules before it stores the object. A ValidatingAdmissionPolicyBinding says where the policy applies and what the API server does when a rule fails. The policy alone does nothing; the binding turns it on.

## Create the policy and the binding

The expression reads the `nodeSelector` of the new Pod. It first checks that the field exists and that the key is present, so a Pod without a node selector fails the rule instead of causing an evaluation error. The binding selects the namespace by its automatic label `kubernetes.io/metadata.name`. Save this as `admissionpolicy-require-tenant-node.yaml`:

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
  - expression: "has(object.spec.nodeSelector) && 'node-restriction.kubernetes.io/tenant' in object.spec.nodeSelector && object.spec.nodeSelector['node-restriction.kubernetes.io/tenant'] == 'tenant-e'"
    message: "Pods must select node-restriction.kubernetes.io/tenant=tenant-e"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-tenant-node-tenant-e
spec:
  policyName: require-tenant-node
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tenant-e-034-030-03-03
```

Apply it:

```sh
kubectl apply -f admissionpolicy-require-tenant-node.yaml
```

Then check the result with server-side dry runs. The flag `--dry-run=server` sends the request through every admission check, but the API server does not store the Pod:

```sh
kubectl -n tenant-e-034-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n tenant-e-034-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --overrides='{"spec":{"nodeSelector":{"node-restriction.kubernetes.io/tenant":"tenant-e"}}}' --dry-run=server
kubectl -n starfleet-034-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
```

The output is:

```text
The pods "test" is invalid: : ValidatingAdmissionPolicy 'require-tenant-node' with binding 'require-tenant-node-tenant-e' denied request: Pods must select node-restriction.kubernetes.io/tenant=tenant-e
pod/test created (server dry run)
pod/test created (server dry run)
```

The API server refused the Pod without a selector in the tenant namespace. It accepted the Pod with the selector, and it accepted the Pod in `starfleet-034-030-03-03`, because the binding does not match that namespace.

## Fix the Deployment

The policy checks only `CREATE` requests, so the Pod that already runs stays. The next new Pod is a different story. A `kubectl rollout restart` at this point shows the effect: the ReplicaSet controller tries to create a Pod from the old template, and the API server refuses it. The events of the namespace then show (shortened to the first line):

```text
Error creating: pods "tenant-e-app-56fd4db5d5-mnq79" is forbidden: ValidatingAdmissionPolicy 'require-tenant-node' with binding 'require-tenant-node-tenant-e' denied request: Pods must select node-restriction.kubernetes.io/tenant=tenant-e
```

The fix is to add the selector to the Pod template. Save this as `deployment-tenant-e-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-e-app
  namespace: tenant-e-034-030-03-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tenant-e-app
  template:
    metadata:
      labels:
        app: tenant-e-app
    spec:
      nodeSelector:
        node-restriction.kubernetes.io/tenant: tenant-e
      containers:
      - name: app
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep infinity
```

Apply it:

```sh
kubectl apply -f deployment-tenant-e-app.yaml
kubectl -n tenant-e-034-030-03-03 rollout status deployment/tenant-e-app --timeout=180s
```

Then check the result:

```sh
kubectl -n tenant-e-034-030-03-03 get pods -o wide
```

The output (columns shortened) shows the new Pod `Running` on the worker. The old Pod shows `Terminating` for about 30 seconds, until the kubelet stops its `sleep` process:

```text
NAME                            READY   STATUS        ...   NODE
tenant-e-app-77b755796b-hvfgx   1/1     Running       ...   astro-ats-034-lab-030-03-03-worker
tenant-e-app-79d8bbb857-dhvlf   1/1     Terminating   ...   astro-ats-034-lab-030-03-03-worker
```

When you are done, remove the lab with `astrona destroy ats-034-lab-030-03-03`.

## Common pitfalls

> [!WARNING]
> An expression such as `object.spec.nodeSelector['node-restriction.kubernetes.io/tenant'] == 'tenant-e'` without the `has()` and `in` checks fails with an evaluation error on a Pod without a selector. With `failurePolicy: Fail` the API server still refuses the Pod, but the error does not show your message.
>
> A binding without `matchResources` applies the policy to every namespace, including `kube-system`. Always limit the binding to the tenant namespace.
>
> The policy does not touch running Pods. A Deployment with the old template keeps its Pod until the next rollout, and then the rollout stops with `FailedCreate` events.
