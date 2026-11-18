---
exam_objectives:
- Use appropriate pod security standards
---
# Enforce Baseline And Preview Restricted

Allow about 8 minutes for the tasks.

The `starfleet` team must move to the Restricted profile later. Today the namespace must block privileged Pods, and every developer must already see what Restricted would reject.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-01-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-010-01-03` runs the Pod `shuttle`, a `docker.io/library/busybox:1.37.0` container with no security settings. The namespace has no Pod Security label.

## Tasks

1. In `starfleet-034-010-01-03`, enforce the Baseline profile.
2. Warn about and audit every Pod that breaks the Restricted profile.
3. Pin all three modes to the Kubernetes version `v1.35`, so a cluster upgrade does not change the rules.
4. Keep the `shuttle` Pod running.

## Check your work

```sh
kubectl -n starfleet-034-010-01-03 run privileged-check --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -- sleep 3600
kubectl -n starfleet-034-010-01-03 run plain-check --image=docker.io/library/busybox:1.37.0 --dry-run=server -- sleep 3600
```

The first command must fail with `violates PodSecurity "baseline:v1.35"`. The second must print a line that starts with `Warning: would violate PodSecurity "restricted:v1.35"` and then `pod/plain-check created (server dry run)`. The audit annotations go to the API server audit log, which this lab does not switch on, so the grader reads the `audit` labels for that mode.
