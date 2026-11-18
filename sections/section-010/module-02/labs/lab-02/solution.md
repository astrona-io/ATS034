---
exam_objectives:
- Use appropriate pod security standards
---
# Drop All Capabilities And Block Privilege Escalation Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Linux splits the power of root into capabilities. A capability is one named privilege, for example `CAP_CHOWN` to change the owner of any file. The kernel shows the capabilities of a process in `/proc/<pid>/status` as hexadecimal bit masks. `CapEff` is the set that the kernel checks now, and `CapBnd` is the bounding set, the upper limit the process can ever reach. Look at the starting state:

```sh
kubectl -n starfleet-034-010-02-02 exec courier -- id
kubectl -n starfleet-034-010-02-02 exec courier -- grep -E 'CapEff|CapBnd|NoNewPrivs' /proc/1/status
kubectl -n starfleet-034-010-02-02 exec courier -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok'
```

```text
uid=0(root) gid=0(root) groups=0(root),10(wheel)
CapEff:	00000000a80425fb
CapBnd:	00000000a80425fb
NoNewPrivs:	0
chown-ok
```

The mask `a80425fb` is the default set of the container runtime, and it includes `CAP_CHOWN`, so root can give the file to user 1000. `NoNewPrivs: 0` means that the `no_new_privs` flag is off: a program with the setuid bit could still raise the privileges of the process.

Two fields of the container `securityContext` change this. `capabilities.drop: ["ALL"]` removes every capability from the bounding set and from the other sets. `allowPrivilegeEscalation: false` makes the container runtime set `no_new_privs` on the process, so neither the process nor its children can gain privileges through setuid programs or file capabilities. Both fields exist only at the container level.

The security settings of a running container cannot change, so the Pod must be deleted and created again. Save this as `pod-courier.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: courier
  namespace: starfleet-034-010-02-02
  labels:
    app: courier
spec:
  containers:
  - name: courier
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Delete the old Pod and apply the new one:

```sh
kubectl -n starfleet-034-010-02-02 delete pod courier
kubectl apply -f pod-courier.yaml
kubectl -n starfleet-034-010-02-02 wait --for=condition=Ready pod/courier --timeout=120s
```

Then check the result:

```sh
kubectl -n starfleet-034-010-02-02 exec courier -- id
kubectl -n starfleet-034-010-02-02 exec courier -- grep -E 'CapEff|CapBnd|NoNewPrivs' /proc/1/status
kubectl -n starfleet-034-010-02-02 exec courier -- sh -c 'touch /tmp/owned && chown 1000 /tmp/owned && echo chown-ok'
```

```text
uid=0(root) gid=0(root) groups=0(root),10(wheel)
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
chown: /tmp/owned: Operation not permitted
command terminated with exit code 1
```

The process still runs as user ID 0, but the kernel now checks capabilities, not the user ID, for privileged operations. Without `CAP_CHOWN` the `chown` call fails with `Operation not permitted`, and the empty bounding set means the process can never get the capability back. `NoNewPrivs: 1` shows that the runtime set the flag.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-02-02`.

## Common pitfalls

> [!WARNING]
> - `kubectl apply` on the running Pod with the new `securityContext` fails, because most Pod fields cannot be updated. Delete the Pod first.
> - `drop: ["ALL"]` at the Pod level is not a valid field. `capabilities` and `allowPrivilegeEscalation` exist only in the container `securityContext`.
> - Do not add `runAsUser` or `runAsNonRoot`. The task keeps the process as root, and the grader checks that it still runs as user ID 0.
