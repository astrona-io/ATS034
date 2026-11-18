---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Restricted With Namespace Labels Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Pod Security Admission is an admission controller inside the API server. It reads the labels of the namespace that a new Pod belongs to and compares the Pod with the profile named in the label. The label `pod-security.kubernetes.io/enforce` makes the API server reject every Pod that breaks the profile. So the whole task is two namespace labels.

Save this as `namespace-starfleet.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet-034-010-01-01
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

Save this as `namespace-outpost.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: outpost-034-010-01-01
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

Apply them:

```sh
kubectl apply -f namespace-starfleet.yaml
kubectl apply -f namespace-outpost.yaml
```

The second command prints two warnings before `namespace/outpost-034-010-01-01 configured`:

```text
Warning: existing pods in namespace "outpost-034-010-01-01" violate the new PodSecurity enforce level "restricted:latest"
Warning: drifter: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

The API server checks the running Pods when the `enforce` label changes, and it only warns. It does not stop or remove `drifter`. The command `kubectl label namespace <name> pod-security.kubernetes.io/enforce=<profile>` gives the same result as the files.

Then check the result:

```sh
kubectl get namespace starfleet-034-010-01-01 outpost-034-010-01-01 --show-labels
kubectl -n starfleet-034-010-01-01 run privileged-check --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -- sleep 3600
kubectl -n starfleet-034-010-01-01 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
kubectl -n outpost-034-010-01-01 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The output looks like this. The last error message is shortened here; the full line names the container in each rule:

```text
NAME                      STATUS   AGE   LABELS
starfleet-034-010-01-01   Active   31s   kubernetes.io/metadata.name=starfleet-034-010-01-01,pod-security.kubernetes.io/enforce=baseline
outpost-034-010-01-01     Active   31s   kubernetes.io/metadata.name=outpost-034-010-01-01,pod-security.kubernetes.io/enforce=restricted
Error from server (Forbidden): pods "privileged-check" is forbidden: violates PodSecurity "baseline:latest": privileged (container "privileged-check" must not set securityContext.privileged=true)
pod/plain-check created (server dry run)
Error from server (Forbidden): pods "plain-check" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (...), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)
```

Baseline rejects the privileged Pod and admits the plain Pod, because running as root with the default capabilities gives no direct access to the node. Restricted rejects the plain Pod and lists all four rules it breaks. A Pod that sets `runAsNonRoot: true`, a `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false` and `drop: ["ALL"]` passes in `outpost-034-010-01-01`. The `shuttle` and `drifter` Pods keep running.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> - Use `--dry-run=server` for the test. A client-side dry run never reaches the admission controller, so it admits every Pod.
> - Check the label key letter by letter. A key such as `pod-security.kubernetes.io/enforced` is ignored, and the namespace stays unchecked.
> - Do not delete the existing Pods to "apply" the label. The `enforce` label checks new Pods only; running Pods stay as they are.
