---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Exceptions, Upgrades And Ongoing Checks

A rollout ends when every namespace has a label. The security of the result then depends on three questions that come later. What happens to the workloads that really need node access? What happens to the rules when the cluster is upgraded? And who is allowed to remove the labels? This part answers each one with a design choice and a check you can run.

## Give node-level workloads their own namespace

Some workloads cannot meet Baseline: a log collector that reads a `hostPath` directory, a network plugin, a node monitoring agent. The profiles are all-or-nothing for a namespace, so the clean answer is to separate them. Put these workloads in a namespace of their own, label that namespace `privileged` explicitly, and enforce Baseline or Restricted everywhere else. A reviewer can then see in one place which workloads have node access.

Save this as `namespace-node-agents.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: node-agents
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: v1.35
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/audit-version: v1.35
---
apiVersion: v1
kind: Namespace
metadata:
  name: applications
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-node-agents.yaml
```

The `node-agents` namespace enforces Privileged but warns and audits against Baseline. Every request that needs more than Baseline therefore leaves a trace in the audit log, while nothing is blocked. Test the difference with the same privileged Pod in both namespaces. Save this Pod as `pod-privileged-agent.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: agent-check
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

Send it to each namespace as a server-side dry run:

```sh
kubectl apply -n node-agents -f pod-privileged-agent.yaml --dry-run=server
kubectl apply -n applications -f pod-privileged-agent.yaml --dry-run=server
```

The first request is accepted, and `kubectl` prints a warning that the Pod would violate `baseline:v1.35`. The second request fails with a `Forbidden` error for `restricted:v1.35`. The same Pod is a recorded exception in one namespace and a rejection in the other.

## Versions and cluster upgrades

The profile definitions change slowly between Kubernetes versions. A label such as `enforce: restricted` without a version label means `latest`: the rules of the API server version that runs now. After a cluster upgrade, `latest` can mean new rules, and a Pod that was admitted before can be rejected when it is recreated. A pinned label such as `enforce-version: v1.35` keeps the rules fixed.

Pinning does not mean never moving. The modes are independent, so you can test the next version in `warn` while `enforce` stays pinned. Apply the next step to the `applications` namespace:

```sh
kubectl label namespace applications pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/warn-version=latest
kubectl get namespace applications -L pod-security.kubernetes.io/enforce-version,pod-security.kubernetes.io/warn-version
```

The listing shows `v1.35` for enforcement and `latest` for warnings. Deployments applied to this namespace now produce a warning when they would fail the newest rules, long before `enforce-version` moves. The sequence for an upgrade is therefore: keep `enforce-version` pinned, set `warn-version` and `audit-version` to `latest`, fix what the warnings show, upgrade the cluster, and then move `enforce-version`.

## Who can change the labels

A label protects only as long as nobody removes it. The labels are fields on the namespace object, and any user with permission to update namespaces can change or delete them. A user with that permission can lower `enforce` to `privileged` and create any Pod. Application teams should not have the verbs `update` or `patch` on namespaces. Check what an account can do with `kubectl auth can-i`:

```sh
kubectl auth can-i update namespaces --as=system:serviceaccount:applications:default
kubectl auth can-i create pods --as=system:serviceaccount:applications:default -n applications
```

The first answer is `no`: the default service account has no permission to update a namespace. The second answer is also `no`, because the account has no Role either. Both answers come from RBAC (role-based access control, the API authorization system), not from Pod Security Admission. Admission and RBAC work together: RBAC decides who may create objects and change labels, and admission decides which Pods are acceptable.

## Keep the check running

Three habits keep the result in place:

- Create every namespace with its labels in the same manifest, so a namespace never exists without them. A namespace without labels in a cluster with a Privileged default is unprotected until someone notices.
- Test every manifest with `kubectl apply --dry-run=server` in the pipeline that deploys it. The dry run goes through Pod Security Admission and shows the same error that the live cluster shows.
- Repeat the inventory from time to time: list the labels, then run the label dry run for the next stricter profile. A new workload or a changed default can open a gap.

You now have the whole life cycle for a namespace: inventory, staged labels, cluster defaults, exceptions in their own namespace, version control and a guard on who changes the labels. Pod Security Admission stays a check on the Pod spec. It does not check images, network access or the Secrets that a Pod can read.

## Common pitfalls

> [!WARNING]
> - **Exempting a whole namespace to get one workload running.** Move that workload to a labelled Privileged namespace and keep the rest enforced.
> - **Leaving labels without a version in a cluster that upgrades.** The rules change with the cluster. Pin the version and test the next one in `warn`.
> - **Giving application teams permission to update namespaces.** They can then remove the labels. Keep that permission with the platform team.
> - **Creating namespaces first and labelling them later.** Between the two steps the namespace uses the cluster default.
