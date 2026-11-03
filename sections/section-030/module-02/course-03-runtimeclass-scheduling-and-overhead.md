---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# RuntimeClass Scheduling And Overhead

Only some nodes of a real cluster have a sandbox handler, and a sandbox uses memory that the container itself does not. If the scheduler does not know both facts, it places a sandboxed Pod on a node that cannot run it, or it overcommits a node. A `RuntimeClass` carries two optional blocks, `scheduling` and `overhead`, that give the scheduler those facts. This part shows what each block adds to a Pod and what happens when they conflict with the Pod.

## What the API server adds to a Pod

A **RuntimeClass admission plugin** in the API server runs when a Pod is created. It reads the class named in `runtimeClassName` and changes the Pod before it is stored. It copies `overhead.podFixed` into the field `spec.overhead`. It merges `scheduling.nodeSelector` into the Pod's `nodeSelector` and adds the class `tolerations` to the Pod's tolerations.

The scheduler then adds the overhead to the Pod's requests when it picks a node. The kubelet counts it for eviction decisions, and a `ResourceQuota` counts it for compute quota. The merge is the only way the class affects scheduling, so the node must carry the label that the class names.

## Create the class, the label and a Pod

The playground handler is `runc`, so the example works without a sandbox install. The class below selects nodes with the label `sandbox: "true"` and adds a fixed overhead. Save this as `runtimeclass-sandboxed.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: sandboxed
handler: runc
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

Label the worker node that has the handler. This step is the administrator's job on a real cluster, and it must match the handler installation:

```sh
kubectl label node astro-ats-034-playground-030-02-worker sandbox=true
```

Save this Pod as `pod-sandboxed-app.yaml`:

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

Apply it and wait:

```sh
kubectl apply -f pod-sandboxed-app.yaml
kubectl -n tenant-b wait --for=condition=Ready pod/sandboxed-app --timeout=120s
```

The manifest has no `nodeSelector` and no `overhead`. Read what the API server stored:

```sh
kubectl -n tenant-b get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}'
```

The first line shows the fixed CPU and memory from the class. The second shows the merged selector. The third shows that the scheduler chose the labeled worker.

## When the Pod and the class disagree

If the Pod sets a `nodeSelector` key that the class also sets, the values must be equal. A different value makes the API server reject the Pod, because the Pod would match no node. A Pod cannot set `spec.overhead` itself either: the plugin rejects a Pod whose overhead differs from the class. These checks prevent a tenant from hiding the cost or moving a sandboxed Pod to an unprepared node.

If no node has the label, the Pod stays `Pending`, and the scheduler event says that no node matched the node selector. Remove the label and create a second Pod to see this case, then restore the label. A `describe` of the second Pod shows the scheduling failure.

A sandbox node is often also tainted so that ordinary Pods stay away. The class `tolerations` list then lets sandboxed Pods onto the node, while the `nodeSelector` pulls them there. A taint alone repels other Pods, and a toleration alone does not attract.

You can now predict the fields that a class adds to a Pod and explain a Pending sandboxed Pod. A cluster still lets users leave out `runtimeClassName`, so the next part rejects such Pods.

## Common pitfalls

> [!WARNING]
> - **Defining `scheduling` but never labeling the nodes.** The merged selector matches nothing, and the Pod stays Pending.
> - **Labeling nodes without installing the handler.** The Pod is scheduled and then fails to create its sandbox.
> - **Omitting `overhead`.** The scheduler and quota undercount the sandbox memory.
> - **Setting a conflicting `nodeSelector` value in the Pod.** The API server rejects the Pod.
> - **Expecting a toleration to pull Pods to a node.** Only the node selector attracts.
