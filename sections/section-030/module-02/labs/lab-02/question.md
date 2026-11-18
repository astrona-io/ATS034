---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Schedule Pods With A RuntimeClass Overhead And Node Selector

Allow about 10 minutes for the tasks.

Tenant B wants its sandboxed workloads to run only on the node prepared for them, and the scheduler must count the extra memory and CPU that a sandbox uses.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The cluster has two nodes: `astro-ats-034-lab-030-02-02-control-plane` and `astro-ats-034-lab-030-02-02-worker`. The namespace `tenant-b-034-030-02-02` is empty. No RuntimeClass exists, and no node has a `sandbox` label.

This kind cluster has only one container runtime handler: `runc`, the default low-level runtime that starts ordinary Linux containers. The RuntimeClass in this task therefore uses the handler `runc`. It practises the overhead and scheduling fields of a RuntimeClass. It does not add a gVisor or Kata Containers sandbox.

## Tasks

1. Create the RuntimeClass `sandboxed` with the handler `runc`, a fixed Pod overhead of `50m` CPU and `64Mi` memory, and the scheduling node selector `sandbox: "true"`.
2. Label the worker node `sandbox=true`. Do not label the control-plane node.
3. In `tenant-b-034-030-02-02`, run the Pod `sandboxed-app` with `runtimeClassName: sandboxed`, the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep infinity"`. Do not write a node selector or an overhead in the Pod: the API server must add them from the RuntimeClass.

## Check your work

```sh
kubectl -n tenant-b-034-030-02-02 get pod sandboxed-app -o jsonpath='{.spec.overhead}{"\n"}{.spec.nodeSelector}{"\n"}{.spec.nodeName}{"\n"}'
```

The three lines must show the overhead of the class, the node selector `sandbox: true` and the worker node name.
