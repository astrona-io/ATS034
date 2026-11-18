---
exam_objectives:
- Use appropriate pod security standards
---
# Admit A Node Agent And Protect Pod Security Labels

Allow about 12 minutes for the tasks.

The `log-agent` must read the log files of the node, but its namespace blocks it. At the same time, an audit found that a deployment account could switch off Pod Security for any namespace.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `node-agents-034-010-03-03` enforces `baseline` at `v1.35`. It holds the Deployment `log-agent`, which runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity` and mounts the node directory `/var/log` at `/host-logs` through a `hostPath` volume named `node-logs`. Its ReplicaSet cannot create a Pod.

The namespace `starfleet-034-010-03-03` enforces `restricted` at `v1.35`. Its ServiceAccount `deployer` manages Deployments there through the Role and RoleBinding `deployer`. The ServiceAccount is also bound to a ClusterRole that lets it update and patch namespaces.

## Tasks

1. Let the `log-agent` Pod run in `node-agents-034-010-03-03`: enforce `privileged` pinned to `v1.35` on that namespace only. Keep the `hostPath` volume as it is.
2. On the same namespace, set the `warn` and `audit` modes to `baseline` pinned to `v1.35`, so every privileged Pod there stays visible.
3. Make sure the `deployer` ServiceAccount can no longer update or patch any namespace. It must still manage Deployments in `starfleet-034-010-03-03`.

## Check your work

```sh
kubectl -n node-agents-034-010-03-03 rollout status deployment/log-agent
kubectl -n node-agents-034-010-03-03 exec deploy/log-agent -- ls /host-logs
kubectl auth can-i patch namespaces --as=system:serviceaccount:starfleet-034-010-03-03:deployer
kubectl auth can-i create deployments -n starfleet-034-010-03-03 --as=system:serviceaccount:starfleet-034-010-03-03:deployer
```

The rollout must finish, the agent must list the node log directory, and the two `can-i` answers must be `no` and `yes`.
