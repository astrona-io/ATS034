---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Pod Security Admission Modes

Switching a namespace straight to `enforce: restricted` rejects every Pod that does not comply, including the Pods of applications that already run there. Pod Security Admission therefore has three modes, so an administrator can measure the effect of a profile before it blocks anything. This part explains the three modes, the version pin, and the order of steps for a safe rollout. It ends with a graded task.

## Three modes and two labels each

A **mode** says what Pod Security Admission does when a Pod violates a profile. Each mode has its own namespace label, and each label value is a profile name. The labels start with `pod-security.kubernetes.io/`:

- `enforce` rejects the Pod. The API server returns an error and stores nothing.
- `audit` accepts the Pod and adds an annotation to the audit log event for the request. A cluster administrator reads it in the API server audit log, if auditing is on.
- `warn` accepts the Pod and sends a warning to the client, so `kubectl` prints it.

Each mode has a second label with the suffix `-version`, for example `pod-security.kubernetes.io/enforce-version`. It holds `latest` or a Kubernetes minor version such as `v1.35`. The profile definitions change slowly between Kubernetes releases. With `latest`, the namespace follows the rules of the API server's own version. With `v1.35`, the rules stay fixed when the cluster is upgraded. If the version label is missing, the value is `latest`.

The three modes are independent. A namespace can enforce Baseline, and warn and audit with Restricted. Developers then see what a move to Restricted would break, while nothing is rejected that Baseline allows.

## See the modes work

Save this as `namespace-modes-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: modes-demo
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

Apply it:

```sh
kubectl apply -f namespace-modes-demo.yaml
```

Save a Pod that is plain, so it meets Baseline and fails Restricted, as `pod-plain-modes.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: plain-pod
  namespace: modes-demo
spec:
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply it:

```sh
kubectl apply -f pod-plain-modes.yaml
```

Then check the result:

```sh
kubectl -n modes-demo get pod plain-pod
```

Before the Pod is created, `kubectl` prints a line that starts with `Warning: would violate PodSecurity "restricted:latest"` and lists the Restricted rules that the Pod breaks. The Pod is then created, and `kubectl get pod` shows that it is running. The `warn` label produced the warning, the `enforce` label allowed the Pod, and the `audit` label wrote an annotation to the audit log that this session does not show.

## Change the label and see existing Pods

Raising the enforcement level does not remove running Pods. Pod Security Admission checks a Pod when it is created or updated, and it never evicts a Pod that is already running. The API server does check existing Pods when you change an `enforce` label, so it can warn you. You can ask that question without changing anything, with a server-side dry run of the label change:

```sh
kubectl label namespace modes-demo pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server
```

The command prints a warning that names the existing Pod `plain-pod` and lists what it violates under Restricted, and it ends with `namespace/modes-demo labeled (server dry run)`. The dry run changed nothing. This is the safe way to find the workloads that block a stricter label.

## A safe rollout in four steps

Use this order when you add Pod Security labels to a namespace that already runs workloads:

1. Set `warn` and `audit` to the target profile. Nothing is rejected.
2. Read the warnings and the audit annotations, and fix each workload.
3. Run the server-side dry run of the `enforce` label and check that no warning remains.
4. Set `enforce` to the target profile, with a version label that fixes the rules.

The task after this part follows the end state of that rollout on a new namespace. Namespace `restricted` must enforce Restricted at `v1.35`, a compliant Pod must run there, and a privileged Pod must be rejected by Pod Security Admission.

You now know what each mode does and how to preview a stricter label. What remains is how the checks behave for Pods that controllers create, because a Deployment does not create Pods itself.

## Common pitfalls

> [!WARNING]
> - **Expecting `warn` or `audit` to block a Pod.** Only `enforce` rejects.
> - **Expecting `enforce` to remove running Pods.** It does not. Existing Pods keep running until they are recreated, and then they are checked.
> - **Leaving the version label out and upgrading the cluster.** `latest` follows the new Kubernetes version, so the rules of the namespace can change with an upgrade. Pin the version when you need stable rules.
> - **Spelling a label wrong.** A misspelled label such as `pod-security.kubernetes.io/enforced` is ignored, and the namespace stays unprotected. The label key must match exactly.
