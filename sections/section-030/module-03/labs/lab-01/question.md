---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Dedicate A Node To One Tenant

Solve this question on: `terminal`

The `tenant-c` team must run on its own machine and no other namespace may use it. The environment has an empty namespace `tenant-c-034-030-03-01` and two nodes. The worker node has no tenant label and no taint.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-01" || exit 1
node_name="astro-ats-034-lab-030-03-01-control-plane"
worker_name="astro-ats-034-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 7 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Label the worker node `tenant=tenant-c`.
2. Taint the worker node `tenant=tenant-c:NoSchedule`.
3. Create the Deployment `tenant-c-app` in `tenant-c-034-030-03-01` with one replica, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Give its Pod template the node selector `tenant: tenant-c` and a toleration for the taint, so that the Pod runs on the dedicated worker.

## Constraints

- Do not label or taint the control-plane node.
- Use the `Equal` operator in the toleration.

## How the answer is checked

The grader runs three checks: the `tenant` label on the worker node; the `tenant=tenant-c:NoSchedule` taint on the worker node; and the selector and toleration of `tenant-c-app`, a finished rollout, and its Pod running on the worker node.

Hint: A taint only keeps other Pods away. The node selector is what pulls the tenant Pod onto the node.
