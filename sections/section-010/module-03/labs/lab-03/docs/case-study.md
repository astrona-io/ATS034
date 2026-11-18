---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `node-agents-034-010-03-03` enforces `baseline` at `v1.35`. It holds the Deployment `log-agent`, which runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity` and mounts the node directory `/var/log` at `/host-logs` through a `hostPath` volume named `node-logs`. Its ReplicaSet cannot create a Pod.

The namespace `starfleet-034-010-03-03` enforces `restricted` at `v1.35`. Its ServiceAccount `deployer` manages Deployments there through the Role and RoleBinding `deployer`. The ServiceAccount is also bound to a ClusterRole that lets it update and patch namespaces.
