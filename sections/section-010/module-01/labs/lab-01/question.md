---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Restricted With Namespace Labels

Allow about 8 minutes for the tasks.

The `starfleet` namespace must stop privileged Pods but keep running ordinary Pods. The `outpost` namespace must accept only Pods that are fully hardened.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-01-01` runs the Pod `shuttle`, and the namespace `outpost-034-010-01-01` runs the Pod `drifter`. Both Pods run `docker.io/library/busybox:1.37.0` with no security settings. Neither namespace has a Pod Security label, so Pod Security Admission checks nothing in them.

## Tasks

1. Make Pod Security Admission enforce the Baseline profile in `starfleet-034-010-01-01`.
2. Make Pod Security Admission enforce the Restricted profile in `outpost-034-010-01-01`.
3. Do not delete or change the `shuttle` and `drifter` Pods.

## Check your work

A server-side dry run sends a Pod through the admission chain of the API server but stores nothing:

```sh
kubectl -n starfleet-034-010-01-01 run privileged-check --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -- sleep 3600
kubectl -n starfleet-034-010-01-01 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
kubectl -n outpost-034-010-01-01 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The first and the third command must fail with `violates PodSecurity`. The second must print `created (server dry run)`. The grader also sends a Pod that meets Restricted to `outpost-034-010-01-01`, and that Pod must be admitted.
