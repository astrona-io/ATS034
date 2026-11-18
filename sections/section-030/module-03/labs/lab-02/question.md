---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Use A NodeRestriction Label For Tenant Placement

Allow about 10 minutes for the tasks.

Tenant D places its Pods with the node label `tenant=tenant-d`. The kubelet of any node can set that label on its own node, so a taken-over node could pull tenant D's Pods onto itself.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-02" || exit 1
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context. Each kind node is a container: `"$engine" exec "$cluster-worker" ...` runs a command on the worker node, not on your computer.

## Starting state

The cluster has two nodes: `astro-ats-034-lab-030-03-02-control-plane` and `astro-ats-034-lab-030-03-02-worker`. The worker node has the plain label `tenant=tenant-d`. The Deployment `tenant-d-app` in `tenant-d-034-030-03-02` runs one Pod with the node selector `tenant: tenant-d`. The kubelet of the worker uses the kubeconfig `/etc/kubernetes/kubelet.conf` on the worker node.

## Tasks

1. As the cluster administrator, label the worker node `node-restriction.kubernetes.io/tenant=tenant-d`.
2. Change the Deployment `tenant-d-app` so that its Pod template selects only `node-restriction.kubernetes.io/tenant: tenant-d`, and wait until the new Pod runs.
3. Remove the plain label `tenant` from the worker node.
4. Prove that the kubelet credentials of the worker cannot change the protected label: run `kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node ...` on the worker node and read the error.

## Check your work

```sh
kubectl get node "$cluster-worker" --show-labels
kubectl -n tenant-d-034-030-03-02 get pods -o wide
"$engine" exec "$cluster-worker" kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node "$cluster-worker" node-restriction.kubernetes.io/tenant=tenant-x --overwrite
```

The node must show the protected label and no `tenant=` label. The Pod must run on the worker. The last command must fail with `Forbidden`.
