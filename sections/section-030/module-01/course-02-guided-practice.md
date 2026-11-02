---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Guided Practice: Compose A Tenant Namespace Boundary

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-030-01" || exit 1
node_name="astro-ats-034-playground-030-01-control-plane"
worker_name="astro-ats-034-playground-030-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create tenant-a enforcing restricted Pod Security, a three-Pod ResourceQuota tenant-budget and a default-deny ingress/egress NetworkPolicy tenant-isolation. Run a Ready restricted tenant-reader with no token mount. Its attempted request to the healthy probe Service ClusterIP must time out. Namespace policies are layered controls, not a claim of separate-kernel isolation.

Save this as `namespace-tenant-a.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-budget
  namespace: tenant-a
spec:
  hard:
    pods: '3'
---
apiVersion: v1
kind: Pod
metadata:
  name: tenant-reader
  namespace: tenant-a
  labels:
    app: tenant-reader
spec:
  restartPolicy: Never
  containers:
  - name: reader
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
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: scratch
    emptyDir: {}
  automountServiceAccountToken: false
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

Apply the scoped correction:

```sh
kubectl apply -f namespace-tenant-a.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n tenant-a wait --for=condition=Ready pod/tenant-reader --timeout=180s
```

Combine admission, a resource budget, token minimization and network isolation for one tenant. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.


## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
