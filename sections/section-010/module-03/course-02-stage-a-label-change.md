---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Stage A Label Change

The three modes exist so that a namespace can move to a stricter profile in steps. `warn` tells the person who runs `kubectl` about a problem. `audit` records it for the administrators. `enforce` blocks. A staged change uses them in that order, so each group learns about a problem before it becomes an outage. This part works through a full change on a namespace that already runs a Deployment, and it ends with a graded task on two namespaces.

## The order and the reason for it

The steps below are the order for a namespace that runs workloads:

1. Set `warn` and `audit` to the target profile and pin their versions. No request is rejected.
2. Collect the warnings from the people who deploy and the annotations from the audit log, and list the workloads to fix.
3. Change the workloads and apply them. The warning disappears when the Pod template meets the profile.
4. Run the server-side dry run of the `enforce` label. No warning must remain.
5. Set `enforce` to the target profile with a pinned version.

Step 4 matters because `warn` checks the objects you apply now, and the dry run checks every Pod that exists now. A Pod that nobody has touched for months only appears in the dry run.

## Build the starting point

Create a namespace with a Deployment that does not meet Restricted. Save this as `namespace-stage-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: stage-demo
```

Apply it:

```sh
kubectl apply -f namespace-stage-demo.yaml
```

Save this Deployment as `deployment-crew.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crew
  namespace: stage-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: crew
  template:
    metadata:
      labels:
        app: crew
    spec:
      containers:
      - name: crew
        image: docker.io/library/busybox:1.37.0
        command: ["sleep", "3600"]
```

Apply it and wait for the rollout:

```sh
kubectl apply -f deployment-crew.yaml
kubectl -n stage-demo rollout status deployment/crew --timeout=120s
```

Both replicas run, because the namespace has no label. This is the state of most namespaces when a rollout starts.

## Step 1 and 2: warn and audit

Add the two labels with the version pinned:

```sh
kubectl label namespace stage-demo pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/warn-version=v1.35 pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/audit-version=v1.35
```

The label command itself prints a warning that names the two existing `crew` Pods, because the API server checks existing Pods when a label changes. The Pods keep running. Now restart the Deployment. The restart updates the Pod template, so you see the warning that a developer would see when a workload changes:

```sh
kubectl -n stage-demo rollout restart deployment/crew
```

The command prints a warning that begins with `would violate PodSecurity "restricted:v1.35"` and lists the rules that the Pod template breaks. The change goes through, because only `warn` and `audit` are set. The rollout creates new Pods that still violate the profile. This is the signal for step 3: the warning names what to fix and does not stop work.

## Step 3 and 4: fix the workload and test

Save the corrected Deployment as `deployment-crew.yaml`, replacing the earlier file:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crew
  namespace: stage-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: crew
  template:
    metadata:
      labels:
        app: crew
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: crew
        image: docker.io/library/busybox:1.37.0
        command: ["sleep", "3600"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

Apply it and wait:

```sh
kubectl apply -f deployment-crew.yaml
kubectl -n stage-demo rollout status deployment/crew --timeout=120s
```

The apply prints no `would violate` warning, and the rollout completes with Pods that follow the profile. Check that no Pod of the old revision is left, and then run the dry run of the `enforce` label:

```sh
kubectl -n stage-demo get pods
kubectl label namespace stage-demo pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server
```

The pod list shows only Pods of the new revision, and the dry run ends with `namespace/stage-demo labeled (server dry run)` and no warning above it.

## Step 5: enforce and verify

Apply the final labels. The version pin is part of the change:

```sh
kubectl label namespace stage-demo pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35 --overwrite
kubectl get namespace stage-demo -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/enforce-version
```

The listing shows `restricted` and `v1.35`. Prove that enforcement works by sending a root Pod as a dry run:

```sh
kubectl -n stage-demo run root-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The command fails with a `Forbidden` error that says the Pod violates `restricted:v1.35`. The namespace now has the end state of the rollout. The task after this part asks for the same end state on two existing namespaces, with a different profile for each.

You have seen the whole sequence: three modes in order, the dry run as the last gate, and a version pin. What stays open is what happens in a namespace with no label, which the cluster configuration decides.

## Common pitfalls

> [!WARNING]
> - **Setting `enforce` first.** The first sign of a problem is then a missing Pod, with no earlier warning.
> - **Pinning only `enforce-version`.** The `warn` and `audit` modes have their own version labels. Without them they follow `latest`.
> - **Trusting a clean `warn` result.** `warn` checks only what you apply. A Pod that nobody redeploys shows up in the label dry run.
> - **Expecting the label to restart old Pods.** The label never removes a running Pod. The failure appears when the Pod is next created.
