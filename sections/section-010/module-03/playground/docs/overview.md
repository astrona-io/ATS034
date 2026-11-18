---
exam_objectives:
- Use appropriate pod security standards
---
# Playground Guide: Plan A Pod Security Rollout

Work in a shell on your own computer. `kubectl`, the Kubernetes command-line tool, normally already points at the playground cluster after the playground starts. A kubeconfig is the file that tells `kubectl` which cluster to use and which credentials to send. To be sure that you work on the playground and not on another cluster, select the playground's kubeconfig and check the context:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-010-03" || exit 1
```

The `test` line stops the shell when the context belongs to another cluster. Keep this shell open while you work through the pages of the module.

## Look at the starting state

This playground is a `kind` cluster with one control plane node and one worker node. The `starfleet` namespace runs two `probe` Pods behind the `probe` Service and a `shuttle` client Pod, and the `outpost` namespace runs the `drifter` client Pod. Pod Security admission reads three labels on each namespace: `enforce` rejects a Pod that breaks the standard, `warn` returns a warning to the client, and `audit` adds an annotation to the audit log entry. Show all three as columns:

```sh
kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn,pod-security.kubernetes.io/audit
```

```text
NAME                 STATUS   AGE   ENFORCE   WARN   AUDIT
default              Active   30s                    
kube-node-lease      Active   30s                    
kube-public          Active   30s                    
kube-system          Active   30s                    
local-path-storage   Active   26s                    
outpost              Active   6s                     
starfleet            Active   6s                     
```

No namespace has a Pod Security label yet, so the plugin admits every Pod in every namespace.

## Make an inventory before you label

A server-side dry run of the enforce label lists the running Pods that would break the standard, without changing the namespace. Run it for both application namespaces, pinned to version `v1.35`:

```sh
kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
kubectl label --dry-run=server --overwrite namespace outpost pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
```

```text
Warning: existing pods in namespace "starfleet" violate the new PodSecurity enforce level "restricted:v1.35"
Warning: probe-7db6ffd7d6-crs55 (and 2 other pods): allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/starfleet labeled (server dry run)
Warning: existing pods in namespace "outpost" violate the new PodSecurity enforce level "restricted:v1.35"
Warning: drifter: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/outpost labeled (server dry run)
```

Every Pod in both namespaces would break Restricted. Enforcing it now would not stop the running Pods, but the next Pod that a controller creates would be rejected. A `warn` label at Restricted is the safe first step for such a namespace.

## Check the API server configuration

A label is not the only way to set a standard. The API server can also read cluster-wide defaults from an admission configuration file, given with the flag `--admission-control-config-file`. Read the admission flags of the API server Pod:

```sh
kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep -E 'admission|enable'
```

```text
"--enable-admission-plugins=NodeRestriction"
"--enable-bootstrap-token-auth=true"
```

The flag `--admission-control-config-file` is missing, so the cluster has no defaults. The `PodSecurity` plugin is on by default and does not need to be listed in `--enable-admission-plugins`.

## Check who can change the labels

Anyone who may update a namespace may also lower its Pod Security labels. Check the permission for the `default` ServiceAccount in `starfleet`:

```sh
kubectl auth can-i update namespaces --as=system:serviceaccount:starfleet:default
```

```text
no
```

The `default` ServiceAccount cannot change namespaces, so Pods in `starfleet` cannot remove their own protection.

## Common pitfalls

> [!WARNING]
> - The inventory dry run reports only Pods that run now. A Deployment with zero replicas, or a CronJob, shows nothing until it creates a Pod.
> - Enforcing a standard does not stop running Pods. The rejection appears later, in the `FailedCreate` events of the controller.
> - An exempt namespace or a cluster default does not show up as a namespace label. Check the API server configuration as well as the labels.
