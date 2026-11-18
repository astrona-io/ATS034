---
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment That Pod Security Admission Blocks

Allow about 10 minutes for the tasks.

The `scanner` Deployment was accepted, but it has no running Pod. Find out why and repair it without weakening the namespace.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-01-04` enforces the Restricted profile, pinned to `v1.35`. It holds the Deployment `scanner` with two replicas. Its Pod template has one container `scanner` that runs `docker.io/library/busybox:1.37.0` with the command `sleep infinity` and has no security settings. The Deployment shows `0/2` Ready Pods.

## Tasks

1. Find the event that explains why the `scanner` Deployment has no Pods.
2. Repair the Pod template of `scanner` so the Pods meet Restricted and run as user ID `1000`.
3. Keep the name, the replica count, the selector, the image and the command of the Deployment.
4. Do not change the labels of the namespace.

## Check your work

```sh
kubectl -n starfleet-034-010-01-04 rollout status deployment/scanner --timeout=120s
kubectl -n starfleet-034-010-01-04 exec deployment/scanner -- id
```

The rollout must finish with `deployment "scanner" successfully rolled out`, and `id` must show `uid=1000`. The grader also reads `/proc/1/status` in each Pod: `NoNewPrivs` must be `1`, `Seccomp` must be `2` and `CapEff` must be all zeros.
