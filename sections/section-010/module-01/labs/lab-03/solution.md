---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Preview Restricted Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Pod Security Admission has three modes, and each mode has its own namespace label. `enforce` rejects a Pod, `warn` sends a warning to the client and `audit` adds an annotation to the audit log event. The modes are independent, so one namespace can enforce Baseline and warn and audit with Restricted. Each mode also has a `-version` label. The value `v1.35` fixes the rules of that Kubernetes version; without it the namespace follows `latest`, the version of the API server.

Save this as `namespace-starfleet.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet-034-010-01-03
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.35
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-starfleet.yaml
```

The command prints `namespace/starfleet-034-010-01-03 configured`. The running `shuttle` Pod meets Baseline, so the new `enforce` label produces no warning about it.

Then check the result:

```sh
kubectl -n starfleet-034-010-01-03 run privileged-check --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -- sleep 3600
kubectl -n starfleet-034-010-01-03 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The output looks like this. The warning is shortened here; the full line names the container in each rule:

```text
Error from server (Forbidden): pods "privileged-check" is forbidden: violates PodSecurity "baseline:v1.35": privileged (container "privileged-check" must not set securityContext.privileged=true)
Warning: would violate PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (...), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)
pod/plain-check created (server dry run)
```

The `enforce` label rejected the privileged Pod, and the message names `baseline:v1.35`, so the version pin works. The plain Pod passed `enforce`, and the `warn` label printed what Restricted would reject. The `audit` label adds the same finding to the audit log of the API server when auditing is on.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-01-03`.

## Common pitfalls

> [!WARNING]
> - Only `enforce` rejects a Pod. A namespace with `warn: restricted` alone accepts every Pod and only prints warnings.
> - Each mode has its own `-version` label. Setting `enforce-version` does not pin `warn` or `audit`.
> - If the message still says `restricted:latest` or `baseline:latest`, the version label for that mode is missing or misspelled.
