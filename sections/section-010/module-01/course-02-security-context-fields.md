---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Security Context Fields

A profile tells you what is forbidden. The Pod spec must then say, field by field, that the Pod does none of it. These fields live in a block called `securityContext`. This part shows where each field goes, which value wins when a field appears twice, and how a Pod with a read-only root filesystem still gets a directory to write to.

## Two levels of securityContext

A `securityContext` is a block of settings that controls the privileges of a Pod or of one container. It can appear at two levels, and some fields exist at only one level.

At the Pod level, under `spec.securityContext`, the settings apply to every container in the Pod:

- `runAsUser`, `runAsGroup` and `runAsNonRoot` choose the user and group ID of the container processes, and refuse to start a process as root.
- `fsGroup` sets the group that owns the files of mounted volumes, so a non-root user can write to them.
- `seccompProfile` selects the seccomp profile. Seccomp (secure computing mode) is a Linux kernel feature that filters which system calls a process may make. The type `RuntimeDefault` uses the filter that the container runtime ships.
- `supplementalGroups`, `seLinuxOptions` and `sysctls` also live here.

At the container level, under `spec.containers[].securityContext`, the settings apply to one container:

- `allowPrivilegeEscalation` decides whether a process can gain more privileges than its parent, for example through a setuid binary. Setting it to `false` sets the Linux `no_new_privs` flag.
- `capabilities` adds or drops Linux capabilities. A capability is one slice of root's power, such as binding to a low port or changing file owners.
- `privileged` gives the container almost all the power of root on the node.
- `readOnlyRootFilesystem` mounts the container's root filesystem read-only.
- `runAsUser`, `runAsGroup`, `runAsNonRoot` and `seccompProfile` can also be set here.

When the same field is set at both levels, the container-level value wins for that container. The Pod Security profiles check the final, merged value, so a container can break Restricted even when the Pod level looks correct.

## A Pod that meets Restricted

The following Pod sets every field that Restricted needs. It also sets `readOnlyRootFilesystem`, which is optional, and mounts a writable `emptyDir` volume for the one place where the application needs to write. Save this as `namespace-restricted-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-demo
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-restricted-demo.yaml
```

Save this as `pod-hardened-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-reader
  namespace: restricted-demo
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  volumes:
  - name: scratch
    emptyDir: {}
```

Apply it and wait for it to start:

```sh
kubectl apply -f pod-hardened-reader.yaml
kubectl -n restricted-demo wait --for=condition=Ready pod/hardened-reader --timeout=120s
```

The first command prints `pod/hardened-reader created`, which means Pod Security Admission accepted the Pod under Restricted. The second prints that the Pod condition is met.

## Check what the kernel enforces

An accepted Pod only proves that the spec contains the right fields. To see that the container process really runs with them, read the process status that Linux keeps for process 1 of the container:

```sh
kubectl -n restricted-demo exec hardened-reader -- id
kubectl -n restricted-demo exec hardened-reader -- grep -E 'NoNewPrivs|Seccomp:|CapEff' /proc/1/status
```

The `id` command shows user ID 1000 and group ID 1000, not 0. The status file shows `NoNewPrivs` with the value `1` (from `allowPrivilegeEscalation: false`), `Seccomp` with the value `2` (a seccomp filter is active) and `CapEff` as all zeros (the container has no effective capabilities). Each value traces back to one field, and the kernel, not Kubernetes, enforces them.

Now test the filesystem. The root filesystem is read-only, and only `/scratch` is a volume:

```sh
kubectl -n restricted-demo exec hardened-reader -- touch /tmp/test-file
kubectl -n restricted-demo exec hardened-reader -- touch /scratch/test-file
```

The first command fails with `Read-only file system`, even for the `/tmp` directory, because `/tmp` is part of the root filesystem. The second command succeeds, because the `emptyDir` volume is writable and `fsGroup: 1000` gives the group of the process access to it. This is the usual pattern for applications that write temporary files: keep the root filesystem read-only and mount an `emptyDir` at each directory that must be writable, for example `/tmp`.

## Where a Pod still fails

Meeting the profile does not guarantee that the application works. Three failures are common:

- The image runs as root and the Pod sets `runAsNonRoot: true` without `runAsUser`. The Pod is admitted, but the kubelet refuses to start the container and reports `CreateContainerConfigError`. Set `runAsUser` to a non-zero ID, or use an image that declares a non-root `USER`.
- The application writes to a path that is not a volume. With a read-only root filesystem, the write fails inside the application, not in Kubernetes. Look at the application log, then add an `emptyDir` for that path.
- The application binds to a port below 1024 as a non-root user without the `NET_BIND_SERVICE` capability. Restricted allows adding back that single capability, or the application can listen on a higher port.

You now know which fields make a Pod meet Restricted and how to check them on the running process. The open question is where to switch the check on, and how to roll it out to a namespace without breaking existing workloads.

## Common pitfalls

> [!WARNING]
> - **Putting a container-only field at the Pod level.** `allowPrivilegeEscalation`, `capabilities`, `privileged` and `readOnlyRootFilesystem` exist only in the container `securityContext`. At the Pod level, the API server rejects the unknown field.
> - **Forgetting `drop: ["ALL"]` in one container.** Restricted checks every container, including init containers and ephemeral containers.
> - **Trusting the Pod spec alone.** Run `grep` on `/proc/1/status` to confirm what the process really has.
> - **Making the root filesystem read-only without a writable volume.** The Pod passes admission and the application then fails at its first write.
