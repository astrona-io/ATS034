---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Isolate A Tenant Namespace And Remove Its Token

Allow about 15 minutes for the tasks.

The `worker` in tenant A needs one thing from the rest of the cluster: the `probe` Service in `starfleet`. Today it can reach every Pod, including the `beacon`, and it carries a ServiceAccount token it never uses.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The cluster uses Calico, a network plugin that enforces NetworkPolicy. The namespace `starfleet-034-030-01-03` runs the Deployment `probe` (two replicas, label `app: probe`, TCP port 8080), the Service `probe` on port 80, the Pod `beacon` (label `app: beacon`, TCP port 8080) and the client Pod `shuttle`. The namespace `tenant-a-034-030-01-03` has the ServiceAccount `worker` and the Pod `worker`, which uses that ServiceAccount and runs the image `docker.io/library/busybox:1.37.0` with the command `sleep infinity`. No NetworkPolicy exists.

## Tasks

1. In `tenant-a-034-030-01-03`, create a NetworkPolicy named `default-deny` that selects every Pod and denies all ingress and all egress traffic.
2. In the same namespace, create a NetworkPolicy named `allow-probe` that allows egress from every Pod only to the `probe` Pods in `starfleet-034-030-01-03`, on TCP port 8080. The `beacon` Pod must stay unreachable.
3. Set `automountServiceAccountToken: false` on the ServiceAccount `worker`. Then recreate the Pod `worker` with the same name, ServiceAccount, image and command, so that it runs without a token.

## Check your work

The policies block DNS, so use IP addresses:

```sh
PROBE_IP=$(kubectl -n starfleet-034-030-01-03 get service probe -o jsonpath='{.spec.clusterIP}')
BEACON_IP=$(kubectl -n starfleet-034-030-01-03 get pod beacon -o jsonpath='{.status.podIP}')
kubectl -n tenant-a-034-030-01-03 exec worker -- wget -q -T 3 -O- http://$PROBE_IP/
kubectl -n tenant-a-034-030-01-03 exec worker -- wget -q -T 3 -O- http://$BEACON_IP:8080/
kubectl -n tenant-a-034-030-01-03 exec worker -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

The first request must return a line with `app=probe`. The second must time out. The `ls` command must fail because the directory does not exist.
