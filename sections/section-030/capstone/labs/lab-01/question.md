---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Isolate An Untrusted Tenant End To End

Combine namespace controls, a sandbox class, a dedicated node, a network policy and an admission policy for one untrusted tenant.

Scenario: the `untrusted` namespace will run code uploaded by customers.

## Starting state

The isolated environment has two healthy probe replicas in `starfleet`, an internal Service, a `shuttle` client and a `drifter` client in `outpost`. The `untrusted` namespace, the sandbox class, the node separation and the admission policy do not exist.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-capstone-030" || exit 1
node_name="astro-ats-034-capstone-030-control-plane"
worker_name="astro-ats-034-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Prepare the worker node and the namespace `untrusted` to run code from an untrusted customer. Do all of the following.

- Create the namespace `untrusted` that enforces the restricted Pod Security profile at version v1.35, and a ResourceQuota `untrusted-budget` with three Pods.
- Label the worker node `isolation=untrusted` and taint it `isolation=untrusted:NoSchedule`.
- Create the RuntimeClass `sandboxed` with the handler `runc`, the node selector `isolation: untrusted` and a toleration for the taint.
- Create the default-deny ingress and egress NetworkPolicy `untrusted-isolation` in `untrusted`.
- Create the ValidatingAdmissionPolicy `require-sandbox` with `failurePolicy: Fail`, matching Pod creation, with the expression `has(object.spec.runtimeClassName) && object.spec.runtimeClassName == 'sandboxed'` and the message `Pods must set runtimeClassName sandboxed`. Bind it with `require-sandbox-untrusted` to the namespace `untrusted` with the action `Deny`.
- Run a Ready Pod `job-runner` in `untrusted` with the sandbox class, no ServiceAccount token mount and a restricted security context. A request from it to the healthy probe Service ClusterIP must time out, and a restricted Pod without the class must be rejected.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
