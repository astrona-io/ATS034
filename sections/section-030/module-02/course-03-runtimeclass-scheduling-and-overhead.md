---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# RuntimeClass Scheduling And Overhead

Only some nodes of a real cluster have a sandbox handler, and a sandbox uses memory that the container itself does not. If the scheduler does not know both facts, it places a sandboxed Pod on a node that cannot run it, or it overcommits a node. A `RuntimeClass` carries two optional blocks, `scheduling` and `overhead`, that give the scheduler those facts. This part shows what each block adds to a Pod and what happens when they conflict with the Pod.

## What the API server adds to a Pod

A **RuntimeClass admission plugin** in the API server runs when a Pod is created. It reads the class named in `runtimeClassName` and changes the Pod before it is stored. It copies `overhead.podFixed` into the field `spec.overhead`. It merges `scheduling.nodeSelector` into the Pod's `nodeSelector` and adds the class `tolerations` to the Pod's tolerations.

The scheduler then adds the overhead to the Pod's requests when it picks a node. The kubelet counts it for eviction decisions, and a `ResourceQuota` counts it for compute quota. The merge is the only way the class affects scheduling, so the node must carry the label that the class names.

## Create the class and a Pod before the label

Run the commands in a shell on the playground VM (virtual machine), which you open with `astrona ssh astro-ats-034-playground-030-02`. The playground cluster has one node, and its containerd has the gVisor handler `runsc`. The class below uses that handler, selects nodes with the label `sandbox: "true"` and adds a fixed overhead. Save this as `runtimeclass-sandboxed.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: sandboxed
handler: runsc
overhead:
  podFixed:
    cpu: 50m
    memory: 64Mi
scheduling:
  nodeSelector:
    sandbox: "true"
```

Apply it:

```sh
kubectl apply -f runtimeclass-sandboxed.yaml
```

The node does not have the label yet. Create a Pod first, so you see what happens when no node matches. Save this as `pod-sandboxed-app.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-app
  namespace: tenant-b
spec:
  runtimeClassName: sandboxed
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply it and look at the Pod and its events after a few seconds:

```sh
kubectl apply -f pod-sandboxed-app.yaml
kubectl -n tenant-b get pod sandboxed-app
kubectl -n tenant-b get events --field-selector involvedObject.name=sandboxed-app
```

The Pod is `Pending`, and the scheduler reports `FailedScheduling` with this message:

```text
0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

The Pod manifest has no `nodeSelector`, so the selector came from the class. The scheduler, not the kubelet, holds the Pod back.

## Label the node and read the merged fields

Labeling the node is the administrator's job on a real cluster. The label must go only on nodes that have the handler installed, because the scheduler trusts the label and does not check containerd. Add it to the playground node:

```sh
kubectl label node astro-ats-034-playground-030-02 sandbox=true
kubectl -n tenant-b wait --for=condition=Ready pod/sandboxed-app --timeout=120s
```

The scheduler retries the Pending Pod and places it on the node. Now read the fields that the API server stored:

```sh
kubectl -n tenant-b get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}'
```

```text
{"cpu":"50m","memory":"64Mi"}
{"sandbox":"true"}
astro-ats-034-playground-030-02
```

The first line is the fixed overhead from the class. The second is the merged selector. The third is the node that the scheduler chose. The node also counts the overhead as a request of the Pod, although the container itself requests nothing:

```sh
kubectl describe node astro-ats-034-playground-030-02 | grep sandboxed-app
```

The line for `sandboxed-app` shows a CPU request of `50m` and a memory request of `64Mi`. The idle gVisor processes of one Pod use about 60 MB on this node, so `64Mi` is a fair estimate for a small Pod. Measure your real workloads before you choose the values.

## When the Pod and the class disagree

The RuntimeClass admission plugin checks that the Pod does not contradict the class. If the Pod sets a `nodeSelector` key that the class also sets, the values must be equal. A server-side dry run runs all admission steps and stores nothing:

```sh
kubectl -n tenant-b run sb-conflict --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server --overrides='{"spec":{"runtimeClassName":"sandboxed","nodeSelector":{"sandbox":"false"}}}' -- sleep 3600
```

```text
Error from server (Forbidden): pods "sb-conflict" is forbidden: conflict: runtimeClass.scheduling.nodeSelector[sandbox] = true; pod.spec.nodeSelector[sandbox] = false
```

A Pod also cannot set its own `spec.overhead` to a different value. The same plugin rejects it with `pod rejected: Pod's Overhead doesn't match RuntimeClass's defined Overhead`. These checks stop a tenant from hiding the cost or moving a sandboxed Pod to an unprepared node.

A sandbox node is often also tainted so that ordinary Pods stay away. The class `tolerations` list then lets sandboxed Pods onto the node, while the `nodeSelector` pulls them there. A taint alone repels other Pods, and a toleration alone does not attract.

You can now predict the fields that a class adds to a Pod and explain a Pending sandboxed Pod. A cluster still lets users leave out `runtimeClassName`, so the sandbox is still optional for anyone who can create Pods.

## Common pitfalls

> [!WARNING]
> - **Defining `scheduling` but never labeling the nodes.** The merged selector matches nothing, and the Pod stays Pending.
> - **Labeling nodes without installing the handler.** The Pod is scheduled and then fails to create its sandbox.
> - **Omitting `overhead`.** The scheduler and quota undercount the sandbox memory.
> - **Setting a conflicting `nodeSelector` value in the Pod.** The API server rejects the Pod.
> - **Expecting a toleration to pull Pods to a node.** Only the node selector attracts.
