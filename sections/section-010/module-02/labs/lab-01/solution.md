---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment To Meet Restricted Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-01" || exit 1
node_name="astro-ats-034-lab-010-02-01-control-plane"
worker_name="astro-ats-034-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The namespace `hardened-034-010-02-01` enforces Restricted. The `scanner` Deployment was accepted, but it has no Ready Pod. Pod Security Admission checks Pods and not Deployments, so the reason is in the events of the ReplicaSet.

Inspect the current objects before changing them:

```sh
kubectl -n hardened-034-010-02-01 get deployment scanner
kubectl -n hardened-034-010-02-01 get replicaset
kubectl -n hardened-034-010-02-01 get events --field-selector reason=FailedCreate
```

The `FailedCreate` event says the Pod violates `restricted:v1.35` and lists the rules the Pod template breaks: privilege escalation, capabilities, the user and the seccomp profile. Fix all of them in the Pod template. The container also writes to `/tmp`, so a read-only root filesystem needs a writable volume at that path.

Save the corrected Deployment as `deployment-scanner.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner
  namespace: hardened-034-010-02-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanner
  template:
    metadata:
      labels:
        app: scanner
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: scanner
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - echo scan > /tmp/result && sleep 3600
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f deployment-scanner.yaml
```

The template changed, so the Deployment creates a new ReplicaSet. The new Pod passes admission and starts.

## Verify The Result

Wait for the rollout, then read the facts from the running process. The kernel and the container runtime, not the Pod spec, decide what the process really has.

```sh
kubectl -n hardened-034-010-02-01 rollout status deployment/scanner --timeout=180s
kubectl -n hardened-034-010-02-01 exec deploy/scanner -- id -u
kubectl -n hardened-034-010-02-01 exec deploy/scanner -- grep NoNewPrivs /proc/1/status
kubectl -n hardened-034-010-02-01 exec deploy/scanner -- cat /tmp/result
kubectl -n hardened-034-010-02-01 exec deploy/scanner -- touch /rootfile
```

The user ID is 1000, `NoNewPrivs` is 1 and `/tmp/result` holds `scan`. The last command must fail because the root filesystem is read-only, and it returns a nonzero status when the restriction works.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-010-02-01`.

## Common pitfalls

> [!WARNING]
> - A rejected Deployment shows its reason in the events of the ReplicaSet. The Deployment itself looks accepted.
> - The Pod level and the container level hold different fields. `allowPrivilegeEscalation`, `capabilities` and `readOnlyRootFilesystem` exist only in the container.
> - A read-only root filesystem stops the write to `/tmp`. The `emptyDir` volume at `/tmp` is what lets the container start.
> - A matching Pod spec does not prove the process uses it. Read `/proc/1/status` and run `id -u` in the Pod.
