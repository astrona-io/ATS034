---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To Strict mTLS With One Exception

Solve this question on: `terminal`

Istio 1.30.5 runs in the cluster. The namespace `starfleet-034-040-02-01` has injection enabled. It holds the `probe` Deployment (two replicas) and the `legacy` Deployment (one replica), each with a Service on port 80, and the client Pod `shuttle` with a sidecar. The namespace `outpost-034-040-02-01` holds the client Pod `drifter` without a sidecar. No `PeerAuthentication` exists, so every request works. The old client in `outpost-034-040-02-01` cannot be given a sidecar this quarter, but everything else in `starfleet-034-040-02-01` must stop accepting plain text.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-01" || exit 1
```

Keep this connection selected for the whole task.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create a `PeerAuthentication` named `namespace-strict` in `starfleet-034-040-02-01` that requires `STRICT` mTLS for every workload in the namespace.
2. Create a `PeerAuthentication` named `legacy-permissive` in `starfleet-034-040-02-01` that selects only the Pods with the label `app: legacy` and sets `PERMISSIVE`.
3. Send the four requests from the two client Pods: `shuttle` reaches both `probe` and `legacy`, and `drifter` reaches `legacy` and fails to reach `probe` with a connection reset.

## Constraints

- Keep Istio and the existing workloads running with their sidecars.
- Do not give `drifter` a sidecar.

## How the answer is checked

The grader runs two checks. The first checks that `namespace-strict` sets `STRICT` with no selector, and that `drifter` cannot reach `probe`. The second checks that `legacy-permissive` selects `app: legacy` with `PERMISSIVE`, and that `drifter` reaches `legacy`. Both also check the sidecars and that `shuttle` reaches `probe` and `legacy`.

Hint: A denied request returns a nonzero status. Wait a few seconds after you apply a policy, because `istiod` must send the new configuration to the sidecars.
