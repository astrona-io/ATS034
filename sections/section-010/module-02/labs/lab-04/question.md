---
exam_objectives:
- Use appropriate pod security standards
---
# Remove Host Networking And A hostPath Volume

Allow about 10 minutes for the tasks.

The `collector` Deployment was written for a namespace without rules. Its namespace now enforces Baseline, and the Deployment has no Pods.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-02-04` enforces the Baseline profile, pinned to version `v1.35`. It holds the Deployment `collector` with one replica. Its Pod template uses the network namespace of the node and mounts the node directory `/var/log` as the volume `logs` at `/logs`. Pod Security Admission rejects every Pod that the ReplicaSet tries to create.

## Tasks

1. Find out from the cluster why the `collector` Deployment has no Pods.
2. Change the Pod template so that the Pod gets its own network namespace and IP address.
3. Keep the volume `logs` mounted at `/logs`, but make it an `emptyDir` volume, so the process can write there without seeing the node files.
4. Do not change the labels of the namespace. Keep the name, image and command of the container.

## Check your work

```sh
kubectl -n starfleet-034-010-02-04 rollout status deployment/collector --timeout=180s
kubectl -n starfleet-034-010-02-04 get pods -l app=collector -o wide
kubectl -n starfleet-034-010-02-04 exec deploy/collector -- ls -A /logs
kubectl -n starfleet-034-010-02-04 exec deploy/collector -- touch /logs/test-file
```

The rollout must finish. The Pod IP address must differ from the node address, `/logs` must not list the `pods` and `containers` directories of the node, and the write must succeed.
