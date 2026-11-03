---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Isolate An Untrusted Tenant End To End Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-030" || exit 1
node_name="astro-ats-034-capstone-030-control-plane"
worker_name="astro-ats-034-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas in `starfleet`, an internal Service, a `shuttle` client and a `drifter` client in `outpost`. The `untrusted` namespace, the sandbox class, the node separation and the admission policy do not exist.

Prepare the worker node and the namespace `untrusted` to run code from an untrusted customer. Do all of the following.

- Create the namespace `untrusted` that enforces the restricted Pod Security profile at version v1.35, and a ResourceQuota `untrusted-budget` with three Pods.
- Label the worker node `isolation=untrusted` and taint it `isolation=untrusted:NoSchedule`.
- Create the RuntimeClass `sandboxed` with the handler `runc`, the node selector `isolation: untrusted` and a toleration for the taint.
- Create the default-deny ingress and egress NetworkPolicy `untrusted-isolation` in `untrusted`.
- Create the ValidatingAdmissionPolicy `require-sandbox` with `failurePolicy: Fail`, matching Pod creation, with the expression `has(object.spec.runtimeClassName) && object.spec.runtimeClassName == 'sandboxed'` and the message `Pods must set runtimeClassName sandboxed`. Bind it with `require-sandbox-untrusted` to the namespace `untrusted` with the action `Deny`.
- Run a Ready Pod `job-runner` in `untrusted` with the sandbox class, no ServiceAccount token mount and a restricted security context. A request from it to the healthy probe Service ClusterIP must time out, and a restricted Pod without the class must be rejected.

Save these objects as `namespace-untrusted.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: untrusted
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: untrusted-budget
  namespace: untrusted
spec:
  hard:
    pods: '3'
```

Save the class as `runtimeclass-sandboxed.yaml`:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: sandboxed
handler: runc
scheduling:
  nodeSelector:
    isolation: untrusted
  tolerations:
  - key: isolation
    operator: Equal
    value: untrusted
    effect: NoSchedule
```

Save the network policy as `networkpolicy-untrusted-isolation.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: untrusted-isolation
  namespace: untrusted
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

Save the policy and the binding as `admissionpolicy-require-sandbox.yaml`:

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
        kubernetes.io/metadata.name: untrusted
```

Save the Pod as `pod-job-runner.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: job-runner
  namespace: untrusted
  labels:
    app: job-runner
spec:
  runtimeClassName: sandboxed
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: runner
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
```

Label and taint the worker node, then apply the objects in this order. The policy applies to Pod creation only, so the Pod comes last:

```sh
kubectl label node "$worker_name" isolation=untrusted
kubectl taint node "$worker_name" isolation=untrusted:NoSchedule
kubectl apply -f namespace-untrusted.yaml
kubectl apply -f runtimeclass-sandboxed.yaml
kubectl apply -f networkpolicy-untrusted-isolation.yaml
kubectl apply -f admissionpolicy-require-sandbox.yaml
```

Wait a few seconds for the binding to take effect, then apply the Pod:

```sh
kubectl apply -f pod-job-runner.yaml
```

## Verify The Result

Wait for the Pod and test the two denials separately, because a denied request returns a nonzero status:

```sh
kubectl -n untrusted wait --for=condition=Ready pod/job-runner --timeout=180s
kubectl -n untrusted get pod job-runner -o wide
```

The Pod runs on the dedicated worker. Send a restricted Pod without the class using a server-side dry run, and the API server must reject it with the policy message. Then send a request from `job-runner` to the ClusterIP of the `probe` Service, which must time out. Read the ClusterIP with `kubectl -n starfleet get service probe`. No example command output is presented as evidence of a completed run.

After recording your result, remove the independent lab with `astrona destroy ats-034-capstone-030`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Create the policy and binding before the Pod, and wait for enforcement. Check each control separately, because one working layer does not prove the others.
