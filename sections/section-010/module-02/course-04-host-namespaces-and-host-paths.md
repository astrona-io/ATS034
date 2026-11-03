---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Host Namespaces And Host Paths

A container normally sees its own network, its own process list and its own filesystem. Linux gives each container these views with namespaces. A Pod spec can switch a view off and share the one of the node instead. It can also mount a directory of the node into the container. Each of these settings lets a process in a container see or change something that belongs to the node or to other Pods, and the Baseline profile rejects all of them. This part explains what each setting exposes and tests the rejection.

## What the host settings expose

The Pod fields below are all checked by Baseline:

- `hostNetwork: true` puts the Pod in the network namespace of the node. The container sees the network interfaces of the node, can listen on node ports, and can reach services that listen only on the loopback address of the node, such as the kubelet or a local agent.
- `hostPID: true` shares the process list of the node. The container can see every process and, with enough privilege, send signals to them or read their environment through `/proc`.
- `hostIPC: true` shares the inter-process communication namespace, so a container can reach shared memory segments of other processes on the node.
- `hostPort` on a container port binds a port on the node. The network plugin must forward it, and it makes scheduling depend on the node.
- A `hostPath` volume mounts a path from the node filesystem. A path such as `/etc` or the container runtime socket gives a process the power to read credentials or start new containers on the node.

Baseline requires every one of these to be absent or `false`. Restricted keeps those rules and also limits the volume types to `configMap`, `csi`, `downwardAPI`, `emptyDir`, `ephemeral`, `persistentVolumeClaim`, `projected` and `secret`. `hostPath` is outside that list.

## Test the rejection

Create a namespace that enforces Baseline:

<!-- astrona:playground:renew -->

Save this as `namespace-host-demo.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: host-demo
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

Apply it:

```sh
kubectl apply -f namespace-host-demo.yaml
```

Save a Pod that shares the network and process namespaces of the node as `pod-host-namespaces.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-namespaces
  namespace: host-demo
spec:
  hostNetwork: true
  hostPID: true
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Send it as a server-side dry run:

```sh
kubectl apply -f pod-host-namespaces.yaml --dry-run=server
```

The command fails with a `Forbidden` error that says the Pod violates `baseline:latest`. The message names the host namespaces setting, and one message covers both `hostNetwork` and `hostPID`. The API server rejected the request, so nothing was scheduled. Now save a Pod that mounts a directory of the node as `pod-host-path.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-path
  namespace: host-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: node-logs
      mountPath: /node-logs
      readOnly: true
  volumes:
  - name: node-logs
    hostPath:
      path: /var/log
```

Send it as a server-side dry run:

```sh
kubectl apply -f pod-host-path.yaml --dry-run=server
```

This request fails too. The message says that `hostPath` volumes are not allowed and names the volume `node-logs`. Setting `readOnly: true` on the mount does not help, because the rule is about the volume type and not about the access mode.

## Replace a hostPath volume

Most applications that use `hostPath` need something else: scratch space, a configuration file, a secret or persistent data. Each has a volume type that Baseline and Restricted accept. Save the corrected Pod as `pod-scratch.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scratch
  namespace: host-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

Send it as a server-side dry run:

```sh
kubectl apply -f pod-scratch.yaml --dry-run=server
```

The command reports that the Pod would be created, with `created (server dry run)` at the end of the line. The `emptyDir` volume lives on the node, but it is created and removed by the kubelet for this Pod, so the Pod cannot reach other paths. Use a `persistentVolumeClaim` for data that must outlive the Pod, a `configMap` or `secret` for configuration, and the `downwardAPI` for Pod metadata.

Some workloads do need the node: a log collector that reads `/var/log`, a network plugin, a node monitoring agent. Pod Security Admission does not remove that need. It makes the decision visible: those Pods run in a namespace that is labelled Privileged on purpose, and ordinary applications run in namespaces that enforce Baseline or Restricted. You now know every setting group that the profiles check. The remaining question is how to apply them to many namespaces without breaking running workloads.

## Common pitfalls

> [!WARNING]
> - **Adding `readOnly: true` to a `hostPath` mount.** The rule rejects the volume type, and the access mode does not matter.
> - **Testing with `kubectl apply --dry-run=client`.** It does not run admission, so the host settings seem to pass. Use `--dry-run=server`.
> - **Using `hostNetwork` to avoid a Service.** The Pod shares the node network and its ports, and it fails Baseline. Expose the Pod with a Service.
> - **Mounting the container runtime socket for convenience.** A process with that socket can start privileged containers on the node, so keep it out of ordinary namespaces.
