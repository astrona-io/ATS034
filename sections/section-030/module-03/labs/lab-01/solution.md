---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Dedicate A Node To One Tenant With Taints And Tolerations Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A dedicated node needs two sides. The node side is a label, which a Pod can select, and a taint, which repels every Pod that does not tolerate it. The Pod side is a node selector, which pulls the Pod to the labelled node, and a toleration, which lets it pass the taint. The label alone attracts no one, and the taint alone keeps everyone out.

## Label and taint the worker

Both commands change the Node object through the API server. The scheduler reads them for every new Pod:

```sh
kubectl label node astro-ats-034-lab-030-03-01-worker tenant=tenant-c
kubectl taint node astro-ats-034-lab-030-03-01-worker tenant=tenant-c:NoSchedule
```

Then check the result:

```sh
kubectl get node astro-ats-034-lab-030-03-01-worker -o jsonpath='{.spec.taints}{"\n"}'
```

The output is `[{"effect":"NoSchedule","key":"tenant","value":"tenant-c"}]`. The effect `NoSchedule` stops new Pods without a toleration. It does not evict Pods that already run on the node.

## Run the tenant Deployment

The Pod template carries both Pod-side settings. The toleration uses the `Equal` operator, so it matches only the key `tenant` with the value `tenant-c`. Save this as `deployment-tenant-c-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-c-app
  namespace: tenant-c-034-030-03-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tenant-c-app
  template:
    metadata:
      labels:
        app: tenant-c-app
    spec:
      nodeSelector:
        tenant: tenant-c
      tolerations:
      - key: tenant
        operator: Equal
        value: tenant-c
        effect: NoSchedule
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
kubectl apply -f deployment-tenant-c-app.yaml
kubectl -n tenant-c-034-030-03-01 rollout status deployment/tenant-c-app --timeout=180s
```

Then check the result:

```sh
kubectl -n tenant-c-034-030-03-01 get pods -o wide
```

The `NODE` column shows `astro-ats-034-lab-030-03-01-worker`. The scheduler placed the Pod on the only node that has the label and whose taint the Pod tolerates.

## Prove that another namespace cannot follow

The `drifter` Pod copies the node selector but has no toleration. Save this as `pod-drifter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost-034-030-03-01
  labels:
    app: drifter
spec:
  nodeSelector:
    tenant: tenant-c
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep infinity
```

Apply it:

```sh
kubectl apply -f pod-drifter.yaml
```

Then check the result:

```sh
kubectl -n outpost-034-030-03-01 get pod drifter
kubectl -n outpost-034-030-03-01 describe pod drifter
```

The Pod shows `Pending`. The events at the end of the `describe` output contain this line (shortened to the message):

```text
Warning  FailedScheduling  5s    default-scheduler  0/2 nodes are available: 2 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
```

The scheduler refused both nodes: the control-plane node has its usual control-plane taint, and the worker has the `tenant` taint. The message counts the nodes but does not print the taints. Read them with `kubectl describe node` when you need the keys.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> Tainting the node after the tenant Pod is running does not test anything for that Pod: `NoSchedule` never evicts running Pods. Create the taint first, or recreate the Pod.
>
> A toleration without a node selector lets the Pod run on the dedicated node, but the scheduler may still place it on another node.
>
> Copying the node selector into another namespace is not enough to reach the node. Only the toleration opens the taint, so a tenant that may set any toleration can still reach the node.
