---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Cap A Tenant With ResourceQuota And LimitRange Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A ResourceQuota limits the totals of one namespace: the number of Pods and the sum of memory requests and limits. The API server checks it each time a Pod is created. A LimitRange sets values for single containers; its admission step writes a default request and limit into every container that declares none. The order matters. A quota on `requests.memory` and `limits.memory` rejects every Pod that has no such values, so the LimitRange must exist before the Pods are created.

Save both objects in one file as `quota-compute-budget.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-budget
  namespace: tenant-a-034-030-01-02
spec:
  hard:
    pods: "2"
    requests.memory: 128Mi
    limits.memory: 256Mi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: container-defaults
  namespace: tenant-a-034-030-01-02
spec:
  limits:
  - type: Container
    defaultRequest:
      memory: 32Mi
    default:
      memory: 64Mi
```

Apply it:

```sh
kubectl apply -f quota-compute-budget.yaml
```

Now create the Deployment. Its container has no `resources` field. Save this as `deployment-burst.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: burst
  namespace: tenant-a-034-030-01-02
spec:
  replicas: 3
  selector:
    matchLabels:
      app: burst
  template:
    metadata:
      labels:
        app: burst
    spec:
      containers:
      - name: burst
        image: docker.io/library/busybox:1.37.0
        command: ["sleep", "3600"]
```

Apply it:

```sh
kubectl apply -f deployment-burst.yaml
```

Then check the result:

```sh
kubectl -n tenant-a-034-030-01-02 get deployment burst
kubectl -n tenant-a-034-030-01-02 get events --field-selector reason=FailedCreate
kubectl -n tenant-a-034-030-01-02 describe resourcequota compute-budget
```

The Deployment shows `2/3` in the `READY` column. The ReplicaSet controller tried to create the third Pod and the API server refused it. Each `FailedCreate` event on `replicaset/burst-...` reads like this one (the Pod name is shortened here):

```text
Error creating: pods "burst-...-dr9cf" is forbidden: exceeded quota: compute-budget, requested: pods=1, used: pods=2, limited: pods=2
```

The quota table shows why. The `pods` row is `2` used of `2` hard. The memory rows are `64Mi` of `128Mi` for requests and `128Mi` of `256Mi` for limits: two Pods with 32Mi and 64Mi each.

Those memory values came from the LimitRange, not from the Deployment. Read them from one Pod:

```sh
kubectl -n tenant-a-034-030-01-02 get pods -l app=burst -o jsonpath='{.items[0].spec.containers[0].resources}'
```

The output is `{"limits":{"memory":"64Mi"},"requests":{"memory":"32Mi"}}`. The LimitRange admission step wrote these values into the Pod when the API server created it.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-01-02`.

## Common pitfalls

> [!WARNING]
> Create the LimitRange before the Deployment. Without defaults, the quota rejects every Pod that has no memory values, and the Deployment shows `0/3`.
>
> The quota error is not on the Deployment's own events. Look at the `FailedCreate` events of the ReplicaSet, or at the `ReplicaFailure` condition in the Deployment status.
