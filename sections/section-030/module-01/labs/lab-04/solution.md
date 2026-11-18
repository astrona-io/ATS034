---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Run A Pod Under gVisor With A RuntimeClass Solution

Open a shell on the lab VM (virtual machine) and confirm that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-030-01-04
kubectl config current-context
```

The output is `kubernetes-admin@astro-ats-034-lab-030-01-04`. Run every command below in this shell.

A RuntimeClass is a cluster-wide Kubernetes object. It maps a name that Pods use to a runtime handler that the container runtime knows. containerd, the container runtime on this node, reads its handlers from `/etc/containerd/config.toml`. gVisor is a sandbox that runs its own kernel in user space for each Pod, and its handler is called `runsc`.

## Check the handler on the node

A RuntimeClass only works if containerd already has a handler with the same name. Look at the runtime tables in the containerd configuration:

```sh
sudo grep -n -A1 'runtimes.runsc' /etc/containerd/config.toml
```

The output shows the table at the end of the file:

```text
275:[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
276-  runtime_type = "io.containerd.runsc.v1"
```

The last part of the table name, `runsc`, is the handler name. The `runtime_type` value tells containerd to start the gVisor shim, `containerd-shim-runsc-v1`, for these Pods.

## Create the RuntimeClass

Save this as `runtimeclass-gvisor.yaml`:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

Apply it:

```sh
kubectl apply -f runtimeclass-gvisor.yaml
```

Then check the result:

```sh
kubectl get runtimeclass
```

```text
NAME     HANDLER   AGE
gvisor   runsc     0s
```

The API server stores the object, but it does not check that the handler exists. containerd checks the handler only when the kubelet asks it to create a Pod sandbox.

## Run the sandboxed Pod

Save this as `pod-sandboxed.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed
  namespace: tenant-a-034-030-01-04
  labels:
    app: sandboxed
spec:
  runtimeClassName: gvisor
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
kubectl apply -f pod-sandboxed.yaml
```

Then check the result:

```sh
kubectl -n tenant-a-034-030-01-04 wait --for=condition=Ready pod/sandboxed --timeout=180s
kubectl -n tenant-a-034-030-01-04 get pod sandboxed
```

The first command prints `pod/sandboxed condition met`, and the Pod shows `1/1 Running`.

## Prove the Pod runs under gVisor

The kernel log inside the Pod comes from the gVisor kernel, not from the Linux kernel of the node:

```sh
kubectl -n tenant-a-034-030-01-04 exec sandboxed -- dmesg
```

The output starts like this (shortened):

```text
[   0.000000] Starting gVisor...
[   0.336232] Segmenting fault lines...
...
[   2.964099] Ready!
```

Next, compare the kernel version inside the Pod with the version of the node:

```sh
kubectl -n tenant-a-034-030-01-04 exec sandboxed -- uname -r
uname -r
```

The Pod reports `4.19.0-gvisor` and the node reports `6.8.0-149-generic`. The Pod talks to the gVisor kernel, so a kernel bug in the node is much harder to reach from it.

Finally, ask containerd which handler it used for the Pod sandbox:

```sh
sudo crictl pods --namespace tenant-a-034-030-01-04 --name sandboxed
sudo crictl pods --namespace tenant-a-034-030-01-04 --name sandboxed -o json | grep runtimeHandler
```

The `RUNTIME` column shows `runsc`, and the JSON line is `"runtimeHandler": "runsc"`.

## Check that shuttle keeps the default handler

The `shuttle` Pod has no `runtimeClassName`, so containerd runs it with the default handler, `runc`:

```sh
sudo crictl pods --namespace starfleet-034-030-01-04 --name shuttle -o json | grep runtimeHandler
kubectl -n starfleet-034-030-01-04 exec shuttle -- uname -r
```

The JSON line is `"runtimeHandler": ""`, which means the default handler. The kernel version is `6.8.0-149-generic`, the same as the node. Running `dmesg` in `shuttle` fails with `dmesg: klogctl: Operation not permitted`, because the container shares the node kernel and may not read its log.

## Common pitfalls

> [!WARNING]
> - The `handler` value must match the containerd table name exactly. `handler: gvisor` creates a valid RuntimeClass, but the Pod stays in `ContainerCreating` with a `FailedCreatePodSandBox` event.
> - A RuntimeClass has no namespace. Do not add `metadata.namespace` to it.
> - `runtimeClassName` is part of the Pod spec and cannot change on a running Pod. Delete the Pod and create it again.
> - `crictl` talks to the containerd socket, which belongs to root. Run it with `sudo`.
