---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Restricted Pod Admission Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-01" || exit 1
node_name="astro-ats-034-lab-010-01-01-control-plane"
worker_name="astro-ats-034-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-034-010-01-01 get pods -o wide
kubectl get nodes -o wide
```

Label namespace `restricted-034-010-01-01` with restricted Pod Security enforcement pinned to v1.35. Run the supplied non-root reader with RuntimeDefault seccomp, no privilege escalation and dropped capabilities. A server-side dry-run privileged Pod creation must be rejected specifically by Pod Security admission. The compliant reader must remain Ready.

Save this as `namespace-restricted.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-034-010-01-01
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
---
apiVersion: v1
kind: Pod
metadata:
  name: restricted-reader
  namespace: restricted-034-010-01-01
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: scratch
    emptyDir: {}
```

Apply the scoped correction:

```sh
kubectl apply -f namespace-restricted.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n restricted-034-010-01-01 wait --for=condition=Ready pod/restricted-reader --timeout=180s
python3 -c 'import json,subprocess; obj={'"'"'apiVersion'"'"': '"'"'v1'"'"', '"'"'kind'"'"': '"'"'Pod'"'"', '"'"'metadata'"'"': {'"'"'name'"'"': '"'"'unsafe-reader'"'"', '"'"'namespace'"'"': '"'"'restricted-034-010-01-01'"'"'}, '"'"'spec'"'"': {'"'"'containers'"'"': [{'"'"'name'"'"': '"'"'reader'"'"', '"'"'image'"'"': '"'"'docker.io/library/busybox:1.37.0'"'"', '"'"'securityContext'"'"': {'"'"'privileged'"'"': True}}]}}; result=subprocess.run(['"'"'kubectl'"'"','"'"'create'"'"','"'"'--dry-run=server'"'"','"'"'-f'"'"','"'"'-'"'"'],input=json.dumps(obj),text=True,capture_output=True,timeout=15); assert result.returncode!=0 and '"'"'violates PodSecurity'"'"' in result.stderr; print('"'"'restricted-admission-denied'"'"')'
```

Admit a compliant Pod and reject a privileged Pod through the API server. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> Namespace labels select the enforced standard. A client-side dry-run does not exercise admission. A malformed request or missing namespace is not the required security rejection.
