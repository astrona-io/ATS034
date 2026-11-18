---
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment That Pod Security Admission Blocks Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Pod Security Admission in `enforce` mode checks Pod objects, not Deployments. The API server stores the Deployment, the Deployment controller creates a ReplicaSet, and the ReplicaSet controller then asks the API server for each Pod. Those Pod requests are rejected, so the reason is an event on the ReplicaSet.

Start with the Deployment and its ReplicaSet:

```sh
kubectl -n starfleet-034-010-01-04 get deployment scanner
kubectl -n starfleet-034-010-01-04 get replicaset
```

```text
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
scanner   0/2     0            0           8s
NAME                 DESIRED   CURRENT   READY   AGE
scanner-77f8b4574c   2         0         0       8s
```

The ReplicaSet wants two Pods and has zero. Read its events:

```sh
kubectl -n starfleet-034-010-01-04 get events --field-selector reason=FailedCreate
```

Each event has a message like this one (shortened here; the full message names the container in each rule):

```text
Error creating: pods "scanner-77f8b4574c-5kzqc" is forbidden: violates PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (...), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)
```

The message lists four rules. Fix all four in the Pod template and add `runAsUser: 1000`, because the `busybox` image runs as root by default. Save the full corrected Deployment as `deployment-scanner.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanner
  namespace: starfleet-034-010-01-04
spec:
  replicas: 2
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
        command: ["sleep", "infinity"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

Apply it:

```sh
kubectl apply -f deployment-scanner.yaml
```

Then check the result:

```sh
kubectl -n starfleet-034-010-01-04 rollout status deployment/scanner --timeout=120s
kubectl -n starfleet-034-010-01-04 exec deployment/scanner -- id
kubectl -n starfleet-034-010-01-04 exec deployment/scanner -- grep -E 'NoNewPrivs|Seccomp:|CapEff' /proc/1/status
```

The rollout ends with `deployment "scanner" successfully rolled out`. The other two commands print:

```text
uid=1000 gid=0(root) groups=0(root)
CapEff:	0000000000000000
NoNewPrivs:	1
Seccomp:	2
```

The changed template made the Deployment create a new ReplicaSet, and its Pods passed admission. The old ReplicaSet stays at zero Pods.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-01-04`.

## Common pitfalls

> [!WARNING]
> - The Deployment itself is accepted, so `kubectl apply` succeeds. When you apply it, the API server only prints a `Warning: would violate PodSecurity` line. Read the ReplicaSet events, not only the apply output.
> - Do not remove or lower the `enforce` label to make the Pods start. The task is to fix the workload.
> - `runAsNonRoot: true` without `runAsUser` passes admission, but the kubelet then refuses to start a `busybox` container, because the image runs as root.
