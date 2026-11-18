---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Schedule Pods With A RuntimeClass Overhead And Node Selector Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A RuntimeClass is a cluster-scoped object that names a container runtime handler. Its `handler` field tells the kubelet which runtime configuration containerd must use. Two other fields matter for scheduling. `overhead.podFixed` is the extra CPU and memory that the sandbox itself uses. `scheduling.nodeSelector` lists node labels that a Pod of this class needs. The RuntimeClass admission plugin in the API server copies both into every new Pod that names the class.

## Create the RuntimeClass

A Pod that names a RuntimeClass that does not exist is refused at once. Try it with a server-side dry run, which sends the request through admission but does not store the Pod:

```sh
kubectl -n tenant-b-034-030-02-02 run early --image=docker.io/library/busybox:1.37.0 --overrides='{"spec":{"runtimeClassName":"sandboxed"}}' --dry-run=server
```

The API server answers `Error from server (Forbidden): pods "early" is forbidden: pod rejected: RuntimeClass "sandboxed" not found`. Now create the class. The handler is `runc` because this kind cluster has no other handler. Save this as `runtimeclass-sandboxed.yaml`:

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

Then check the result:

```sh
kubectl get runtimeclass sandboxed
```

The output shows `sandboxed` with `runc` in the `HANDLER` column.

## Run the Pod and label the node

The Pod names only the class. It has no node selector and no overhead of its own. Save this as `pod-sandboxed-app.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-app
  namespace: tenant-b-034-030-02-02
  labels:
    app: sandboxed-app
spec:
  runtimeClassName: sandboxed
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
kubectl apply -f pod-sandboxed-app.yaml
```

If you apply the Pod before you label the node, the Pod stays `Pending`. The scheduler reports `0/2 nodes are available: 1 node(s) didn't match Pod's node affinity/selector, 1 node(s) had untolerated taint(s).` The worker has no `sandbox` label, and the control-plane node has its usual control-plane taint. Label the worker:

```sh
kubectl label node astro-ats-034-lab-030-02-02-worker sandbox=true
kubectl -n tenant-b-034-030-02-02 wait --for=condition=Ready pod/sandboxed-app --timeout=180s
```

Then check the result:

```sh
kubectl -n tenant-b-034-030-02-02 get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}'
```

The output is:

```text
{"cpu":"50m","memory":"64Mi"}
{"sandbox":"true"}
astro-ats-034-lab-030-02-02-worker
```

The API server added the overhead and the node selector, and the scheduler placed the Pod on the labelled worker. `kubectl describe node astro-ats-034-lab-030-02-02-worker` shows the effect on the node. The `sandboxed-app` line reads `50m (0%)` CPU requests and `64Mi (0%)` memory requests, although its container asks for nothing: the scheduler counts the overhead as part of the Pod.

The admission plugin also refuses a Pod that sets its own different overhead. A dry run with `"overhead":{"cpu":"10m"}` fails with `pod rejected: Pod's Overhead doesn't match RuntimeClass's defined Overhead`.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-02-02`.

## Common pitfalls

> [!WARNING]
> Write the label value as the string `"true"` in the RuntimeClass YAML. A bare `true` is a boolean, and the API server rejects it because label values are strings.
>
> The node selector of the class is added only when the Pod is created. Changing the RuntimeClass later does not move or update running Pods.
>
> A RuntimeClass with the handler `runc` adds no isolation. It only shows how the fields work. A real sandbox needs a handler such as `runsc` (gVisor) that containerd knows.
