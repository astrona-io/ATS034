---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A Tenant Node Selector With A ValidatingAdmissionPolicy

Allow about 12 minutes for the tasks.

Tenant E has a dedicated worker node, but its Pods only land there when their authors remember the node selector. Make the API server refuse every tenant E Pod that forgets it.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The cluster has two nodes: `astro-ats-034-lab-030-03-03-control-plane` and `astro-ats-034-lab-030-03-03-worker`. The worker node has the label `node-restriction.kubernetes.io/tenant=tenant-e`. The namespaces `tenant-e-034-030-03-03` and `starfleet-034-030-03-03` exist. The Deployment `tenant-e-app` in `tenant-e-034-030-03-03` runs one Pod with the image `docker.io/library/busybox:1.37.0` and no node selector. No ValidatingAdmissionPolicy exists.

## Tasks

1. Create a ValidatingAdmissionPolicy named `require-tenant-node`. It matches `CREATE` requests for `pods` and allows a Pod only when its `spec.nodeSelector` has the key `node-restriction.kubernetes.io/tenant` with the value `tenant-e`. Its message is `Pods must select node-restriction.kubernetes.io/tenant=tenant-e`.
2. Create a ValidatingAdmissionPolicyBinding named `require-tenant-node-tenant-e` that applies the policy with the validation action `Deny` to the namespace `tenant-e-034-030-03-03` only.
3. Change the Deployment `tenant-e-app` so that its Pod template sets the node selector `node-restriction.kubernetes.io/tenant: tenant-e`, and wait until its new Pod runs.

## Check your work

```sh
kubectl -n tenant-e-034-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n starfleet-034-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n tenant-e-034-030-03-03 get pods -o wide
```

The first command must fail with the message of the policy. The second must succeed. The `tenant-e-app` Pod must run on the worker node.
