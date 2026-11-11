---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Restricted Pod Admission

Solve this question on: `terminal`

The namespace `restricted-034-010-01-01` must only admit Pods that meet the Restricted Pod Security Standard. It does not exist yet. The environment also runs two healthy `probe` replicas, an internal Service and two client Pods in `starfleet-034-010-01-01` and `outpost-034-010-01-01`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-01" || exit 1
node_name="astro-ats-034-lab-010-01-01-control-plane"
worker_name="astro-ats-034-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the namespace `restricted-034-010-01-01` with the labels `pod-security.kubernetes.io/enforce: restricted` and `pod-security.kubernetes.io/enforce-version: v1.35`.
2. Create the Pod `restricted-reader` in `restricted-034-010-01-01` with `restartPolicy: Never`, one container named `reader`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep 3600"`. At Pod level set `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, `fsGroup: 1000` and the `RuntimeDefault` seccomp profile. In the container set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and drop `ALL` capabilities, and mount an `emptyDir` volume named `scratch` at `/scratch`.
3. Prove the policy: a server-side dry run of a privileged Pod in `restricted-034-010-01-01` must be rejected by Pod Security admission, and `restricted-reader` must stay Ready.

## Constraints

- Do not change the `starfleet-034-010-01-01` and `outpost-034-010-01-01` namespaces or their workloads.
- Use a server-side dry run (`kubectl create --dry-run=server`) for the privileged Pod, so nothing is stored.

## How the answer is checked

The grader runs two checks. The first checks the two Pod Security labels on `restricted-034-010-01-01` and sends a privileged Pod as a server-side dry run, which must fail with a Pod Security violation; a rejection for another reason does not count. The second checks the fields of `restricted-reader`, its `scratch` volume and mount, and that the Pod is Running and Ready.

Hint: `kubectl label` does not create a namespace. Apply a Namespace manifest that carries the labels.
