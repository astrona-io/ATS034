---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Require A RuntimeClass With A ValidatingAdmissionPolicy

Allow about 10 minutes for the tasks.

Jobs from outside the `starfleet` run in the `untrusted` namespace. A RuntimeClass named `sandboxed` exists, but any user can still create a Pod there without it.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-02-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespaces `untrusted-034-030-02-03` and `trusted-034-030-02-03` exist. The RuntimeClass `sandboxed` exists with the handler `runc`, because `runc` is the only runtime handler of this kind cluster. The task grades the admission rule, not a gVisor or Kata Containers sandbox. The Pod `job-runner` runs in `untrusted-034-030-02-03` with the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep infinity"`, and it sets no `runtimeClassName`. No ValidatingAdmissionPolicy exists.

## Tasks

1. Create a ValidatingAdmissionPolicy named `require-sandbox`. It matches `CREATE` requests for `pods` and allows a Pod only when `spec.runtimeClassName` is `sandboxed`. Its message is `Pods must set runtimeClassName sandboxed`.
2. Create a ValidatingAdmissionPolicyBinding named `require-sandbox-untrusted` that applies the policy with the validation action `Deny` to the namespace `untrusted-034-030-02-03` only. Pods in `trusted-034-030-02-03` must not be affected.
3. Recreate the Pod `job-runner` in `untrusted-034-030-02-03` with `runtimeClassName: sandboxed` and the same image and command.

## Check your work

```sh
kubectl -n untrusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n trusted-034-030-02-03 run test --image=docker.io/library/busybox:1.37.0 --dry-run=server
kubectl -n untrusted-034-030-02-03 get pod job-runner -o jsonpath='{.spec.runtimeClassName}{"\n"}'
```

The first command must fail with the message of the policy. The second must succeed. The third must print `sandboxed`.
