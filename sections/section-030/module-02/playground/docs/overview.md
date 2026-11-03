---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Guided Practice: Schedule Sandboxed Pods With A RuntimeClass

Run the exercise below in the module playground. It practises the RuntimeClass, the node label and the merged Pod fields.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-030-02" || exit 1
node_name="astro-ats-034-playground-030-02-control-plane"
worker_name="astro-ats-034-playground-030-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has an empty namespace `tenant-b` and two nodes. The worker node has no sandbox label, and no RuntimeClass exists for sandboxed Pods.

Create the RuntimeClass `sandboxed` with the handler `runc`, a node selector `sandbox: "true"` and a fixed Pod overhead of `50m` CPU and `64Mi` memory. Label the worker node `sandbox=true`. Run the Pod `sandboxed-app` in `tenant-b` with `runtimeClassName: sandboxed`, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Do not set a node selector or overhead in the Pod. The API server must add them from the class, and the scheduler must place the Pod on the labeled worker.

Save this as `runtimeclass-sandboxed.yaml`:

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

Apply it and label the worker node:

```sh
kubectl apply -f runtimeclass-sandboxed.yaml
kubectl label node "$worker_name" sandbox=true
```

Save this as `pod-sandboxed-app.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-app
  namespace: tenant-b
  labels:
    app: sandboxed-app
spec:
  runtimeClassName: sandboxed
  restartPolicy: Never
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-sandboxed-app.yaml
```

## Verify The Result

Wait for the Pod and read the fields that the API server added:

```sh
kubectl -n tenant-b wait --for=condition=Ready pod/sandboxed-app --timeout=180s
kubectl -n tenant-b get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}'
```

The first line shows the class overhead, the second the merged node selector and the third the labeled worker. No example command output is presented as evidence of a completed run. A matching field alone does not show that the scheduler used it, so read the node name as well.


## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Label the node before you judge the Pod. Do not set the node selector or overhead in the Pod yourself, because the class must supply them.
