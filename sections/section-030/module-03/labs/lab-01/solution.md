---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Dedicate A Node To One Tenant Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-01" || exit 1
node_name="astro-ats-034-lab-030-03-01-control-plane"
worker_name="astro-ats-034-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has an empty namespace `tenant-c` and two nodes. The worker node has no tenant label and no taint.

Dedicate the worker node to `tenant-c`. Label it `tenant=tenant-c` and taint it `tenant=tenant-c:NoSchedule`. Create the Deployment `tenant-c-app` in `tenant-c` with one replica, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Give its Pod template the matching node selector and a toleration for the taint, so that the Pod runs on the dedicated worker.

Label and taint the worker node:

```sh
kubectl label node "$worker_name" tenant=tenant-c
kubectl taint node "$worker_name" tenant=tenant-c:NoSchedule
```

Save this as `deployment-tenant-c-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-c-app
  namespace: tenant-c
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tenant-c-app
  template:
    metadata:
      labels:
        app: tenant-c-app
    spec:
      nodeSelector:
        tenant: tenant-c
      tolerations:
      - key: tenant
        operator: Equal
        value: tenant-c
        effect: NoSchedule
      containers:
      - name: app
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
```

Apply it:

```sh
kubectl apply -f deployment-tenant-c-app.yaml
```

## Verify The Result

Wait for the rollout and read the node of the Pod:

```sh
kubectl -n tenant-c rollout status deployment/tenant-c-app --timeout=180s
kubectl -n tenant-c get pods -o wide
```

The node column shows the dedicated worker. No example command output is presented as evidence of a completed run. The taint keeps other Pods off the node, and the selector with the toleration puts this Pod on it, so check that all four settings exist.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Use the effect NoSchedule exactly. A toleration without a node selector does not place the Pod, and a selector without a toleration leaves it Pending.
