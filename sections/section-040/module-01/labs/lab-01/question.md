---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS Between Workloads

Solve this question on: `terminal`

Istio 1.30.5 runs in the cluster. The namespace `starfleet-034-040-01-01` has sidecar injection enabled and runs two `probe` replicas, the `probe` Service and the client Pod `shuttle`, all with sidecars. The namespace `outpost-034-040-01-01` runs the client Pod `drifter` without a sidecar. No `PeerAuthentication` exists, so plain-text requests still work. This verifies one service-mesh boundary, not host traffic or encryption for every possible path.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-01" || exit 1
node_name="astro-ats-034-lab-040-01-01-control-plane"
worker_name="astro-ats-034-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 5 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the `PeerAuthentication` named `namespace-strict` in `starfleet-034-040-01-01` with mTLS mode `STRICT`.
2. Prove the boundary: `shuttle` receives `version=v1` from `http://probe/`, and the plain-text request from `drifter` to `http://probe.starfleet-034-040-01-01/` fails with a connection reset.

## Constraints

- Keep Istio running, and keep the `probe` and `shuttle` Pods injected and Ready.
- Do not give `drifter` a sidecar.

## How the answer is checked

The grader runs one check: the `PeerAuthentication` `namespace-strict` with mode `STRICT`, and the request from `drifter`, which must fail with a connection reset. It also checks that both `probe` Pods and `shuttle` have an `istio-proxy` container, that `drifter` has none, and that `shuttle` still receives `version=v1`.

Hint: Wait a few seconds after you apply the policy, because `istiod` must send the new configuration to the sidecars.
