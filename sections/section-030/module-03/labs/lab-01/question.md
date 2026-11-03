---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Dedicate A Node To One Tenant

Reserve the worker node for one tenant with a label, a taint, a selector and a toleration.

Scenario: the `tenant-c` team must run on its own machine and no other namespace may use it.

## Starting state

The isolated environment has an empty namespace `tenant-c` and two nodes. The worker node has no tenant label and no taint.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-01" || exit 1
node_name="astro-ats-034-lab-030-03-01-control-plane"
worker_name="astro-ats-034-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Dedicate the worker node to `tenant-c`. Label it `tenant=tenant-c` and taint it `tenant=tenant-c:NoSchedule`. Create the Deployment `tenant-c-app` in `tenant-c` with one replica, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Give its Pod template the matching node selector and a toleration for the taint, so that the Pod runs on the dedicated worker.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
