# Service Mesh Identity And Policy Playground

This ungraded playground is a kind cluster (Kubernetes 1.35, one control-plane node and one worker node) with Istio 1.30.5 installed by Helm. The namespace `starfleet` has `istio-injection=enabled` and runs the `probe` Deployment (two replicas, `version=v1`), the `probe` Service on port 80 and the client pod `shuttle`. The namespace `outpost` runs the client pod `drifter` without a sidecar.

`testing/smoke.sh` runs the steps the module pages teach: it checks the sidecars, shows that permissive mode accepts both clients, applies a `STRICT` `PeerAuthentication` (the `drifter` request is reset) and an `AuthorizationPolicy` that allows only the `bridge` ServiceAccount (the `shuttle` request gets `403`). Run it with `scripts/ci/test-playground.sh sections/section-040/module-01/playground`.
