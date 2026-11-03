---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Migrate A Namespace To Strict mTLS With One Exception

Require mTLS for the whole `starfleet` namespace and keep the `legacy` workload reachable for the client without a sidecar.

## Starting state

The isolated environment runs Istio 1.30.5 and has the namespace `starfleet` with injection enabled. It holds the `probe` Deployment (two replicas) and the `legacy` Deployment (one replica), each with a Service on port 80, and the client Pod `shuttle` with a sidecar. The namespace `outpost` holds the client Pod `drifter` without a sidecar. No `PeerAuthentication` exists, so every request works.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-02-01" || exit 1
```

Keep this connection selected for the whole task.

## Required result

The old client in `outpost` cannot be given a sidecar this quarter, but everything else in `starfleet` must stop accepting plain text. Deliver three results and keep Istio and the existing workloads running with their sidecars.

1. **Namespace policy.** A `PeerAuthentication` named `namespace-strict` in `starfleet` requires `STRICT` mTLS for every workload in the namespace.
2. **Exception.** A `PeerAuthentication` named `legacy-permissive` in `starfleet` selects only the Pods with the label `app: legacy` and sets `PERMISSIVE`.
3. **Behaviour.** `shuttle` reaches both `probe` and `legacy`. `drifter` reaches `legacy` and fails to reach `probe` with a connection reset.

## Verify the result

Send the four requests from the two client Pods before you finish. A denied request returns a nonzero status when the denial works. Wait a few seconds after you apply a policy, because `istiod` must send the new configuration to the sidecars.
