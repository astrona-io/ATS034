---
exam_objectives:
- Use appropriate pod security standards
---
# Playground Guide: Check And Enforce Pod Security Standards

Work in a shell on your own computer. `kubectl`, the Kubernetes command-line tool, normally already points at the playground cluster after the playground starts. A kubeconfig is the file that tells `kubectl` which cluster to use and which credentials to send. To be sure that you work on the playground and not on another cluster, select the playground's kubeconfig and check the context:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-010-01" || exit 1
```

The `test` line stops the shell when the context belongs to another cluster. Keep this shell open while you work through the pages of the module.

## Look at the starting state

This playground is a `kind` cluster with one control plane node and one worker node. The `starfleet` namespace runs two `probe` Pods from a Deployment behind the `probe` Service, and a `shuttle` client Pod. The `outpost` namespace runs the `drifter` client Pod. Pod Security admission is the admission plugin in the API server that checks new Pods against a Pod Security Standard, and a namespace label selects the standard. List the namespace labels and the Pods:

```sh
kubectl get namespaces starfleet outpost --show-labels
kubectl -n starfleet get pods
```

```text
NAME        STATUS   AGE   LABELS
starfleet   Active   3s    kubernetes.io/metadata.name=starfleet,project=ckad
outpost     Active   3s    kubernetes.io/metadata.name=outpost,project=outpost
NAME                     READY   STATUS    RESTARTS   AGE
probe-7db6ffd7d6-fzfvw   1/1     Running   0          3s
probe-7db6ffd7d6-x27bl   1/1     Running   0          3s
shuttle                  1/1     Running   0          3s
```

Neither namespace has a `pod-security.kubernetes.io` label, so the plugin admits every Pod in them. The Pod names in your playground end with other random characters.

## Ask what Restricted would break

Before you enforce a standard on a namespace that already runs Pods, ask the API server which Pods would break it. A server-side dry run of the label change runs the check but does not store the label:

```sh
kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted
```

```text
Warning: existing pods in namespace "starfleet" violate the new PodSecurity enforce level "restricted:latest"
Warning: probe-7db6ffd7d6-fzfvw (and 2 other pods): allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/starfleet labeled (server dry run)
```

All three Pods break Restricted for the same four reasons. The label has no version, so the API server checks against `restricted:latest`, the newest version of the standard it knows.

## Enforce Restricted on a new namespace

Create a namespace and enforce Restricted on it, pinned to version `v1.35` of the standard:

```sh
kubectl create namespace restricted-demo
kubectl label namespace restricted-demo pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
```

```text
namespace/restricted-demo created
namespace/restricted-demo labeled
```

Save a privileged Pod as `pod-privileged.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-check
  namespace: restricted-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
```

Send it through admission as a server-side dry run, so nothing is stored even if it passes:

```sh
kubectl apply --dry-run=server -f pod-privileged.yaml
```

```text
Error from server (Forbidden): error when creating "pod-privileged.yaml": pods "privileged-check" is forbidden: violates PodSecurity "restricted:v1.35": privileged (container "check" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "check" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "check" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "check" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "check" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

The API server rejects the Pod and lists every rule it breaks, with the field that would fix each one. The command returns a nonzero exit status, so run it alone and not in a script that stops on the first error. Remove the namespace when you are done with it:

```sh
kubectl delete namespace restricted-demo
```

## Common pitfalls

> [!WARNING]
> - A client-side dry run (`--dry-run=client`) never reaches the admission plugin, so it shows no Pod Security result. Use `--dry-run=server`.
> - A label without `enforce-version` follows `latest`, so the result can change after a cluster upgrade. Pin the version when the result must stay the same.
> - An error about a missing namespace or a malformed file is not a Pod Security rejection. Look for `violates PodSecurity` in the message.
