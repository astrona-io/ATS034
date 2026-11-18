---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Pod That Meets Restricted With A Read-Only Root Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The namespace enforces Restricted, so the API server rejects the Pod unless every Restricted rule is met. The Pod-level `securityContext` holds the fields that apply to all containers: the user ID, `runAsNonRoot` and the seccomp profile. The container-level `securityContext` holds the fields that exist only there: `allowPrivilegeEscalation`, `capabilities` and `readOnlyRootFilesystem`. The `emptyDir` volume gives the process one writable directory on top of the read-only root filesystem.

Save this as `pod-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader
  namespace: starfleet-034-010-01-02
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
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

Apply it:

```sh
kubectl apply -f pod-reader.yaml
kubectl -n starfleet-034-010-01-02 wait --for=condition=Ready pod/reader --timeout=120s
```

The first command prints `pod/reader created`, so Pod Security Admission accepted the Pod. Then check what the kernel enforces on the container process:

```sh
kubectl -n starfleet-034-010-01-02 exec reader -- id
kubectl -n starfleet-034-010-01-02 exec reader -- grep -E 'NoNewPrivs|Seccomp:|CapEff' /proc/1/status
```

```text
uid=1000 gid=0(root) groups=0(root)
CapEff:	0000000000000000
NoNewPrivs:	1
Seccomp:	2
```

The user ID is 1000. The group ID is still 0, because the task does not set `runAsGroup`; Restricted does not require it. `NoNewPrivs: 1` comes from `allowPrivilegeEscalation: false`, `Seccomp: 2` means a seccomp filter is active, and `CapEff` is all zeros because every capability was dropped.

Now test the filesystem. The directory `/tmp` in the image has mode `drwxrwxrwt`, so user 1000 could normally write there:

```sh
kubectl -n starfleet-034-010-01-02 exec reader -- ls -ld /tmp
kubectl -n starfleet-034-010-01-02 exec reader -- touch /tmp/test-file
kubectl -n starfleet-034-010-01-02 exec reader -- touch /scratch/test-file
```

```text
drwxrwxrwt    2 root     root             6 Sep 26  2024 /tmp
touch: /tmp/test-file: Read-only file system
command terminated with exit code 1
```

The write to `/tmp` fails with `Read-only file system`, so the read-only mount, not the file permissions, blocks it. The write to `/scratch` prints nothing and succeeds, because the `emptyDir` volume is writable.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-01-02`.

## Common pitfalls

> [!WARNING]
> - `allowPrivilegeEscalation`, `capabilities` and `readOnlyRootFilesystem` exist only in the container `securityContext`. At the Pod level the API server rejects them as unknown fields.
> - Do not mount the volume at `/tmp` to make the error go away. The task asks for `/scratch`, and the read-only test uses `/tmp`.
> - `runAsNonRoot: true` alone is not enough for this image. The `busybox` image runs as root by default, so without `runAsUser` the kubelet refuses to start the container.
