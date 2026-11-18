---
exam_objectives:
- Use appropriate pod security standards
---
# Playground Guide: Read Pod Security Rejections And Process Settings

Work in a shell on your own computer. `kubectl`, the Kubernetes command-line tool, normally already points at the playground cluster after the playground starts. A kubeconfig is the file that tells `kubectl` which cluster to use and which credentials to send. To be sure that you work on the playground and not on another cluster, select the playground's kubeconfig and check the context:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-010-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-010-02" || exit 1
```

The `test` line stops the shell when the context belongs to another cluster. Keep this shell open while you work through the pages of the module.

## Look at the starting state

This playground is a `kind` cluster with one control plane node and one worker node. The `starfleet` namespace runs two `probe` Pods behind the `probe` Service and a `shuttle` client Pod, and the `outpost` namespace runs the `drifter` client Pod. A third namespace, `hardened`, enforces the Restricted standard and holds the `scanner` Deployment. Show the enforce label of each namespace and the Deployment:

```sh
kubectl get namespaces starfleet outpost hardened -L pod-security.kubernetes.io/enforce
kubectl -n hardened get deployment scanner
```

```text
NAME        STATUS   AGE   ENFORCE
starfleet   Active   3s    
outpost     Active   3s    
hardened    Active   3s    restricted
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
scanner   0/1     0            0           3s
```

The API server stored the Deployment, but it has no Pod. Pod Security admission checks Pods, not Deployments, so the Deployment itself was never rejected.

## Find the reason in the events

The ReplicaSet controller creates the Pods of a Deployment. When admission rejects a Pod, the controller records a `FailedCreate` event. Read the message of that event:

```sh
kubectl -n hardened get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message --no-headers | head -1
```

```text
Error creating: pods "scanner-59c787d7cd-gs5pv" is forbidden: violates PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (container "scanner" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "scanner" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "scanner" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "scanner" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

The message lists four broken rules and names the field that fixes each one. The Pod name in your playground ends with other random characters. The event can take a few seconds to appear after the playground starts; run the command again if it prints nothing.

## Read the settings of a running process

The fields in the Pod spec are a request. The kernel shows what the process really got. The `shuttle` Pod in `starfleet` sets no security fields, so it shows the defaults of the container runtime:

```sh
kubectl -n starfleet exec shuttle -- id
kubectl -n starfleet exec shuttle -- grep -E 'CapEff|NoNewPrivs|Seccomp:' /proc/1/status
```

```text
uid=0(root) gid=0(root) groups=0(root),10(wheel)
CapEff:	00000000a80425fb
NoNewPrivs:	0
Seccomp:	0
```

The process runs as root (user ID 0). `CapEff` is the set of capabilities the kernel checks now, and `00000000a80425fb` is the default set of the container runtime. `NoNewPrivs: 0` means the process could still gain privileges through a setuid program. `Seccomp: 0` means that no seccomp filter is active. These are the values that `runAsNonRoot`, `capabilities.drop`, `allowPrivilegeEscalation: false` and `seccompProfile` change.

## Common pitfalls

> [!WARNING]
> - A Deployment that shows `0/1` with no Pods is not a scheduling problem. Read the `FailedCreate` events of the namespace before you change anything else.
> - A field in the Pod spec does not prove the result. Check `/proc/1/status` inside the container after a change.
> - Most fields of a running Pod cannot change. A Deployment replaces its Pods when you change the template; a bare Pod must be deleted and created again.
