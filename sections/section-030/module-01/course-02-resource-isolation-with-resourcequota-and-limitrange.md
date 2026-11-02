---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Resource Isolation With ResourceQuota And LimitRange

One tenant that creates too many Pods, or one Pod without a memory limit, can take the CPU and memory that other tenants need. A node that runs out of memory kills processes, and a cluster that runs out of Pod capacity stops scheduling. Resource isolation sets a budget per namespace and a default per container. This part adds both to a namespace and shows what happens at the limit.

## Two objects, two jobs

A **ResourceQuota** limits the total amount of resources that a namespace can use or the number of objects it can hold. The API server checks it when an object is created. Examples are `pods`, `requests.cpu`, `requests.memory`, `limits.memory`, `persistentvolumeclaims` and `services.loadbalancers`. A quota rejects a request that would push the total over the limit.

A **LimitRange** sets rules for single objects in a namespace. For containers it can set minimum and maximum values, and default requests and limits. A **request** is the amount a container asks the scheduler to reserve. A **limit** is the amount the kubelet allows it to use. The LimitRange admission step adds the defaults to a container that has none.

The two objects work together. If a quota covers `requests.memory` or `limits.memory`, every new Pod must declare that value, or the API server rejects it. A LimitRange with defaults gives Pods the value for free, so developers do not have to write it in every manifest.

## Set a budget and a default

Save this as `namespace-quota-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: quota-demo
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-budget
  namespace: quota-demo
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
  namespace: quota-demo
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
kubectl apply -f namespace-quota-demo.yaml
```

The quota allows two Pods, 128 MiB of total requests and 256 MiB of total limits. The LimitRange gives each container a 32 MiB request and a 64 MiB limit when it declares none.

## Reach the limit

Save a Deployment that asks for three replicas as `deployment-burst.yaml`. Its container declares no memory values:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: burst
  namespace: quota-demo
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
kubectl -n quota-demo get deployment burst
kubectl -n quota-demo get events --field-selector reason=FailedCreate
kubectl -n quota-demo describe resourcequota compute-budget
```

The Deployment is accepted, and `get deployment` shows two ready replicas out of three. The event list holds a `FailedCreate` event on the ReplicaSet with a message that starts with `exceeded quota: compute-budget` and names the request (`pods=1`), the current use and the limit. The `describe` output has a table with the columns `Resource`, `Used` and `Hard`: the `pods` row reads `2` of `2`, and the memory rows show the sums of the two Pods that exist.

The quota blocked the third Pod, not the Deployment. This is the same pattern as an admission rejection: the controller that creates the Pod reports the failure on its own object.

## Check the defaults

The Pods did not declare memory, yet the quota counted them. Read what the LimitRange added to one Pod:

```sh
kubectl -n quota-demo get pods -l app=burst -o jsonpath='{.items[0].spec.containers[0].resources}'
```

The output is a JSON object with `limits.memory` of `64Mi` and `requests.memory` of `32Mi`. The LimitRange admission step wrote those values into the Pod at creation. If you delete the LimitRange and create a new Pod, the API server rejects it with a message that the quota requires `limits.memory` and `requests.memory` to be specified. A LimitRange does not change Pods that already exist.

## What the budget protects

Quotas protect the other tenants from the capacity a tenant can claim through the API. Memory limits protect the node from one container: a container that goes over its memory limit is killed by the kernel (`OOMKilled`), and the node and its neighbours keep running. Requests decide scheduling, and limits decide enforcement. A quota does not protect against a noisy neighbour at the CPU level unless CPU limits are set, and it says nothing about network or disk bandwidth.

You now have a namespace with a budget and defaults. The remaining shared resource is the network, where every Pod can still reach every other Pod.

## Common pitfalls

> [!WARNING]
> - **Setting a compute quota without a LimitRange default.** Every Pod that omits requests or limits is rejected, and the error appears on the ReplicaSet, not on the Deployment.
> - **Looking for the quota error on the Deployment.** The Deployment is accepted. Read the ReplicaSet events.
> - **Expecting a LimitRange to change existing Pods.** It applies at creation only.
> - **Assuming the quota stops a single heavy Pod.** The quota limits totals. A limit in the Pod or a `max` in the LimitRange limits one container.
