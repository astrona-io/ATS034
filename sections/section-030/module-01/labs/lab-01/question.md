---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Compose A Tenant Namespace Boundary

Solve this question on: `terminal`

A new tenant gets its own namespace with layered controls: Pod Security, a quota and a default-deny network policy. The environment runs two healthy `probe` replicas and the `probe` Service in `starfleet-034-030-01-01`, and client Pods in `starfleet-034-030-01-01` and `outpost-034-030-01-01`. Namespace policies are layered controls, not a claim of separate-kernel isolation.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-01" || exit 1
node_name="astro-ats-034-lab-030-01-01-control-plane"
worker_name="astro-ats-034-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the namespace `tenant-a-034-030-01-01` with the labels `pod-security.kubernetes.io/enforce: restricted` and `pod-security.kubernetes.io/enforce-version: v1.35`, and the ResourceQuota `tenant-budget` in it that allows at most three Pods.
2. Create the NetworkPolicy `tenant-isolation` in `tenant-a-034-030-01-01` that selects every Pod and denies all ingress and all egress.
3. Run the Pod `tenant-reader` (label `app: tenant-reader`) in `tenant-a-034-030-01-01` with `restartPolicy: Never`, `automountServiceAccountToken: false`, one container named `reader`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep 3600"`. At Pod level set `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, `fsGroup: 1000` and the `RuntimeDefault` seccomp profile. In the container set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and drop `ALL` capabilities, and mount an `emptyDir` volume named `scratch` at `/scratch`.
4. Prove the isolation: a request from `tenant-reader` to the ClusterIP of the `probe` Service must time out, while `shuttle` still reaches it.

## Constraints

- Do not change the `probe` Deployment, its Service or the client Pods.
- Do not add any NetworkPolicy outside `tenant-a-034-030-01-01`.

## How the answer is checked

The grader runs four checks: the Pod Security labels of the namespace; the quota of three Pods; the NetworkPolicy, together with a request from `tenant-reader` to the `probe` ClusterIP that must time out; and the fields of `tenant-reader` and that it is Ready. Every check also needs `shuttle` to reach `probe`, so the denied target is healthy.

Hint: An empty `ingress` and `egress` list with both policy types denies all traffic, including DNS, so use the ClusterIP rather than the Service name.
