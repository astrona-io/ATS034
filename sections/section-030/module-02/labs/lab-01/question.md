---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Schedule Sandboxed Pods With A RuntimeClass

Create a RuntimeClass with scheduling and overhead, and run a Pod that uses it.

Scenario: the `tenant-b` namespace must run its code in the sandbox class on the node that has the handler.

## Starting state

The isolated environment has an empty namespace `tenant-b` and two nodes. The worker node has no sandbox label, and no RuntimeClass exists for sandboxed Pods.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-01" || exit 1
node_name="astro-ats-034-lab-030-02-01-control-plane"
worker_name="astro-ats-034-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the RuntimeClass `sandboxed` with the handler `runc`, a node selector `sandbox: "true"` and a fixed Pod overhead of `50m` CPU and `64Mi` memory. Label the worker node `sandbox=true`. Run the Pod `sandboxed-app` in `tenant-b` with `runtimeClassName: sandboxed`, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Do not set a node selector or overhead in the Pod. The API server must add them from the class, and the scheduler must place the Pod on the labeled worker.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
