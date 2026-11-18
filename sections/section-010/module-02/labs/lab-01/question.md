---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Deployment As A Non-Root User

Allow about 10 minutes for the tasks.

The `probe` application answers HTTP requests for the `shuttle` client. Its process runs as root today, and it must run as an ordinary user without losing its Service.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-02-01` has no Pod Security labels. It runs the Deployment `probe` with two replicas of a small Python HTTP server, the Service `probe` on port 80, and the client Pod `shuttle`. The `probe` image declares no user, so its process runs as user ID 0 (root).

## Tasks

1. Change the Deployment `probe` so that its process runs as user ID `1000`.
2. Make the kubelet refuse to start a `probe` container whose process would run as root.
3. Keep two replicas, the image, the command and the labels of the Pod template as they are.
4. The `shuttle` Pod must still get a reply from `http://probe/`.

## Check your work

```sh
kubectl -n starfleet-034-010-02-01 exec deploy/probe -- id
kubectl -n starfleet-034-010-02-01 exec shuttle -- wget -q -T 3 -O- http://probe/
```

The process must run as `uid=1000`. The reply must start with `version=v1`, and the `host` field names the `probe` Pod that answered.
