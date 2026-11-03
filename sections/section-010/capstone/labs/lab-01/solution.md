---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Apply Pod Security Standards Across Three Namespaces Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-010)"
test "$(kubectl config current-context)" = "kind-ats-034-capstone-010" || exit 1
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

Three namespaces need three decisions. `starfleet` runs the `probe` application as root and has no labels. `outpost` runs a root client and has no labels. `dock` already enforces Restricted, and its `scout` Deployment has no Ready Pod. Start with a read-only look at all three:

```sh
kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn
kubectl -n dock get events --field-selector reason=FailedCreate
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server
```

The event in `dock` lists the rules the `scout` Pod template breaks. The dry run in `starfleet` names the `probe` Pods that fail Restricted. Those Pods keep running when the label is applied, but any restart or rollout would fail until the template is corrected. Fix the templates first, then label the namespaces.

Save the corrected `probe` Deployment as `deployment-probe.yaml`. It keeps the replicas, selector, image, command, readiness probe and volume, and adds the Restricted fields:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
      release: probe
  template:
    metadata:
      labels:
        app: probe
        release: probe
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v1
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 2
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 128Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
      volumes:
      - name: app
        configMap:
          name: probe-code
```

Save the corrected `scout` Deployment as `deployment-scout.yaml`. It writes to `/scratch`, so a read-only root filesystem needs a volume there:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
  namespace: dock
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: scout
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - echo ready > /scratch/state && sleep 3600
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: scratch
          mountPath: /scratch
      volumes:
      - name: scratch
        emptyDir: {}
```

Save the namespace labels as `namespaces-pod-security.yaml`. `starfleet` enforces, warns and audits on Restricted. `outpost` enforces Baseline and warns and audits on Restricted. Every mode is pinned to `v1.35`, and the existing `project` labels stay:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet
  labels:
    project: ckad
    pod-security.kubernetes.io/enforce: restricted
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
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.35
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.35
```

Apply the three files and wait for both rollouts:

```sh
kubectl apply -f deployment-probe.yaml -f deployment-scout.yaml
kubectl apply -f namespaces-pod-security.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n dock rollout status deployment/scout --timeout=180s
```

The namespaces are labelled after the Deployments are corrected, so the `probe` rollout creates Pods that Restricted accepts.

## Verify The Result

Check the application, the processes and the admission decisions separately. Each answers a different question.

```sh
kubectl -n starfleet exec shuttle -- wget -q -T 5 -O- http://probe
kubectl -n starfleet exec deploy/probe -- id -u
kubectl -n dock exec deploy/scout -- cat /scratch/state
kubectl -n dock exec deploy/scout -- touch /rootfile
kubectl -n outpost run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
kubectl -n starfleet run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The `wget` command prints the `probe` response, so the Service still reaches the non-root Pods. The `id -u` command prints 1000. The `cat` command prints `ready`. The `touch` command must fail because the root filesystem is read-only. The plain Pod is admitted in `outpost` under Baseline and rejected in `starfleet` under Restricted.

After recording your result, remove the independent lab with `astrona destroy ats-034-capstone-010`.

## Common pitfalls

> [!WARNING]
> - Label the namespaces after the templates are corrected. A rollout in a namespace that already enforces Restricted fails if the template is not compliant.
> - Restricted does not require a read-only root filesystem. The `scout` task asks for it, and then the application needs a writable volume.
> - An apply that leaves out the `project` label removes it. Keep the existing labels in the file.
> - A rejection counts only when the message says the Pod violates PodSecurity. A client-side dry run never runs admission.
