---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Cap A Tenant With ResourceQuota And LimitRange

Allow about 10 minutes for the tasks.

Tenant A shares the cluster with other tenants and must stay inside a small budget. Its developers do not write memory values in their manifests, so the namespace must add them.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `tenant-a-034-030-01-02` exists and is empty. It has no ResourceQuota and no LimitRange.

## Tasks

1. In `tenant-a-034-030-01-02`, create a ResourceQuota named `compute-budget` that allows at most 2 Pods, 128Mi of total memory requests and 256Mi of total memory limits.
2. In the same namespace, create a LimitRange named `container-defaults` that gives every container a default memory request of 32Mi and a default memory limit of 64Mi.
3. Create a Deployment named `burst` with 3 replicas, the label `app: burst`, one container named `burst`, the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Do not set any resources in the Deployment.

## Check your work

```sh
kubectl -n tenant-a-034-030-01-02 get deployment burst
kubectl -n tenant-a-034-030-01-02 get events --field-selector reason=FailedCreate
```

The Deployment must show 2 of 3 replicas ready, and the events must show that the quota `compute-budget` rejected the third Pod.
