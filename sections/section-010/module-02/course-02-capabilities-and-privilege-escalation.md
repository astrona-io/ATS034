---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Capabilities And Privilege Escalation

Root is not one single power. Linux splits the power of root into units called capabilities, so a process can hold only the ones it needs. A container receives a default set of capabilities from the container runtime, and that set is larger than most applications use. This part shows how to read the capabilities of a running container, how `drop` and `add` change them, and what `allowPrivilegeEscalation` does when a process tries to gain more than it started with.

## Capabilities and the bounding set

A **capability** is one named permission that used to belong only to root. `CHOWN` lets a process change the owner of any file. `NET_BIND_SERVICE` lets it listen on a port below 1024. `NET_ADMIN` lets it change network configuration, and `SYS_ADMIN` covers a very wide range of administrative operations. The kernel keeps several capability sets for each process. Two matter here:

- The effective set (`CapEff`) holds the capabilities that the kernel checks right now.
- The bounding set (`CapBnd`) is the upper limit. A process can never gain a capability that is not in this set, even by running a setuid program.

The container runtime fills the bounding set when it creates the container. The Pod field `securityContext.capabilities` changes it: `drop` removes capabilities from the runtime default, and `add` puts capabilities back or adds new ones. `drop: ["ALL"]` removes every capability. The name `ALL` is special; it is not a real capability.

The Baseline profile accepts only a short list of added capabilities: `AUDIT_WRITE`, `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `MKNOD`, `NET_BIND_SERVICE`, `SETFCAP`, `SETGID`, `SETPCAP`, `SETUID` and `SYS_CHROOT`. Adding `SYS_ADMIN` or `NET_ADMIN` fails Baseline. Restricted is stricter: every container must drop `ALL`, and the only capability it may add back is `NET_BIND_SERVICE`.

## Compare the default set with a dropped set

Create a namespace without Pod Security labels, so that both Pods below are admitted:

<!-- astrona:playground:renew -->

```sh
kubectl create namespace caps-demo
```

Save a Pod that runs as root with the default capabilities as `pod-caps-default.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: caps-default
  namespace: caps-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Save the same Pod with every capability dropped as `pod-caps-dropped.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: caps-dropped
  namespace: caps-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
```

Apply both and wait for them:

```sh
kubectl apply -f pod-caps-default.yaml -f pod-caps-dropped.yaml
kubectl -n caps-demo wait --for=condition=Ready pod/caps-default pod/caps-dropped --timeout=120s
```

Read the capability lines of process 1 in each container:

```sh
kubectl -n caps-demo exec caps-default -- grep Cap /proc/1/status
kubectl -n caps-demo exec caps-dropped -- grep Cap /proc/1/status
```

The first container shows non-zero hexadecimal values in `CapEff` and `CapBnd`. The second shows all zeros in every line, so its process holds no capability at all. Both containers run as user ID 0, which shows that the user ID and the capabilities are separate settings.

Now see a capability change what the process can do. Both containers run as root, so both can create a file. Only the first holds `CHOWN`:

```sh
kubectl -n caps-demo exec caps-default -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok'
kubectl -n caps-demo exec caps-dropped -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok'
```

The first command prints `chown-ok`. The second fails with `Operation not permitted` on the `chown` call, because the kernel checks `CAP_CHOWN` and the effective set of the second container is empty. The user in the second container is still root, but root without capabilities cannot change the owner of a file.

## Privilege escalation and no_new_privs

A program can gain privileges that its parent does not have. A setuid binary does this: when a process runs it, the process takes the user ID of the file owner, which can be root. The field `allowPrivilegeEscalation` controls whether a process may gain more privileges than its parent. When it is `false`, the runtime sets the Linux `no_new_privs` flag on the process, and the kernel then ignores setuid bits and file capabilities when the process runs a new program.

The default is `true`. It is always `true` for a privileged container or a container with `CAP_SYS_ADMIN`, so those settings cannot be combined with `false`. Check the flag in the two running containers:

```sh
kubectl -n caps-demo exec caps-default -- grep NoNewPrivs /proc/1/status
```

The line shows `NoNewPrivs` with the value `0`, because `allowPrivilegeEscalation` was not set. A Pod that sets it to `false` shows `1` on this line. Restricted requires `false` in every container, including init containers.

Combine the two ideas as the profile does. Dropping `ALL` and disabling escalation means the process holds nothing and cannot gain anything. If the application needs one capability, for example to listen on port 80 as a non-root user, add back only that one:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
    add: ["NET_BIND_SERVICE"]
```

This block is valid under Restricted. Any other `add` value is rejected. You can now read the real capabilities of a container and explain what each field changes. Capabilities are only one of the controls the kernel applies; the next part covers the filter on system calls and the two security modules that sit beside it.

## Common pitfalls

> [!WARNING]
> - **Dropping only the capabilities you think are dangerous.** Restricted requires `drop: ["ALL"]`. A list of single names fails the check.
> - **Treating root without capabilities as safe.** The process can still read and write the files its user ID owns, so combine the settings with a non-root user.
> - **Adding `SYS_ADMIN` to make an application start.** It breaks Baseline and gives the container a very wide set of powers. Find the one capability the application needs.
> - **Setting `allowPrivilegeEscalation: false` on a privileged container.** The API server validates the Pod and rejects the contradiction, so the Pod is never created.
