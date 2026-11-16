---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate A Secret And Refresh Its Consumer Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-01" || exit 1
node_name="astro-ats-034-lab-020-01-01-control-plane"
worker_name="astro-ats-034-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-034-020-01-01 get pods -o wide
kubectl get nodes -o wide
```

Update Secret practice-token from disposable-v1 to disposable-v2. Create rotated-reader with the required environment key reference and read-only Secret volume at /credentials. Both values must equal the new disposable credential without printing it. An environment consumer must be recreated to load a changed Secret; a mounted projection has different update behavior.

Save this as `secret-practice-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-token
  namespace: starfleet-034-020-01-01
type: Opaque
stringData:
  token: disposable-v2
---
apiVersion: v1
kind: Pod
metadata:
  name: rotated-reader
  namespace: starfleet-034-020-01-01
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    env:
    - name: PRACTICE_TOKEN
      valueFrom:
        secretKeyRef:
          name: practice-token
          key: token
    volumeMounts:
    - name: secret
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: secret
    secret:
      secretName: practice-token
```

Apply the scoped correction:

```sh
kubectl apply -f secret-practice-token.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet-034-020-01-01 wait --for=condition=Ready pod/rotated-reader --timeout=180s
kubectl -n starfleet-034-020-01-01 exec rotated-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && test "$(cat /credentials/token)" = disposable-v2'
```

Replace a disposable credential and verify both delivery paths use the new value. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-020-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
