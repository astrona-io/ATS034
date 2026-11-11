---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Schedule Sandboxed Pods With A RuntimeClass

Solve this question on: `terminal`

Sandboxed workloads must run only on a node prepared for them. The namespace `tenant-b-034-030-02-01` is empty, and the cluster has two nodes. The worker node has no sandbox label, and no RuntimeClass exists for sandboxed Pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-01" || exit 1
node_name="astro-ats-034-lab-030-02-01-control-plane"
worker_name="astro-ats-034-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 7 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the RuntimeClass `sandboxed` with the handler `runc`, a node selector `sandbox: "true"` and a fixed Pod overhead of `50m` CPU and `64Mi` memory.
2. Label the worker node `sandbox=true`.
3. Run the Pod `sandboxed-app` in `tenant-b-034-030-02-01` with `runtimeClassName: sandboxed`, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`.

## Constraints

- Do not set a node selector or an overhead in the Pod. The API server must add them from the class.
- Do not label or taint the control-plane node.

## How the answer is checked

The name `sandboxed` is only a RuntimeClass name. Its handler is `runc`, so this exercise proves RuntimeClass admission and scheduling, not an additional gVisor or Kata isolation boundary.

The grader runs three checks: the handler, overhead and node selector of the RuntimeClass `sandboxed`; the `sandbox=true` label on the worker node; and that `sandboxed-app` is Ready, carries the overhead and node selector the class added, and runs on the worker node.

Hint: The worker node is the node whose name ends in `-worker`: `kubectl get nodes`.
