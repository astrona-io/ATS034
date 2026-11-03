---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage Pod Security Labels On Two Namespaces Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-ats-034-lab-010-03-01" || exit 1
node_name="astro-ats-034-lab-010-03-01-control-plane"
worker_name="astro-ats-034-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

Neither namespace has Pod Security labels, so nothing is checked. The `probe` and client Pods run as root, which Baseline allows and Restricted does not. Read the labels and ask the API server what each profile would report for the existing Pods:

```sh
kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite --dry-run=server
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server
```

The Baseline dry run gives no Pod warning. The Restricted dry run names the existing Pods and lists the rules they break. So `starfleet` can enforce Baseline now and only warn and audit on Restricted. The `outpost` namespace must enforce Restricted; the existing `drifter` Pod keeps running, because a label never removes a running Pod.

Save this as `namespaces-pod-security.yaml`. Both namespaces keep their `project` label, because an apply replaces the label set it manages:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet
  labels:
    project: ckad
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.35
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.35
---
apiVersion: v1
kind: Namespace
metadata:
  name: outpost
  labels:
    project: outpost
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespaces-pod-security.yaml
```

The command may print a warning that names the Pods in `starfleet` that would not meet Restricted. That warning is the `warn` mode working.

## Verify The Result

Check the labels, then test both namespaces with server-side dry runs. A dry run goes through admission and stores nothing. A Pod with no security settings must be admitted in `starfleet` and rejected in `outpost`.

```sh
kubectl get namespaces starfleet outpost --show-labels
kubectl -n starfleet run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
kubectl -n outpost run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
kubectl -n starfleet get pods
```

The first dry run ends with `created (server dry run)`. The second fails with a `Forbidden` error that says the Pod violates `restricted:v1.35`. The `probe` Pods and the client Pods stay Ready.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-010-03-01`.

## Common pitfalls

> [!WARNING]
> - Namespace labels select the profile. A client-side dry run does not run admission, so use `--dry-run=server`.
> - An apply that leaves out the `project` label removes it. Keep the existing labels in the file.
> - A rejection only counts when the message says the Pod violates PodSecurity. A missing namespace gives a different error.
> - A stricter `enforce` label does not remove running Pods. Read the warnings to learn which Pods will fail when they are recreated.
