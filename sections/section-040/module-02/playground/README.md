# Operate Istio Mutual TLS Playground

This ungraded playground is a kind cluster (Kubernetes 1.35, one control-plane node and one worker node) with Istio 1.30.5 installed by Helm. The namespace `starfleet` has `istio-injection=enabled` and runs the `probe` and `legacy` workloads and the client pod `shuttle`. The namespace `outpost` runs the client pod `drifter` without a sidecar.

`testing/smoke.sh` runs the steps the module pages teach: mesh-wide and namespace `PeerAuthentication` precedence, the migration with a `legacy` exception, the sidecar certificate (`pilot-agent request GET certs`), the `istio_requests_total` metric with `connection_security_policy="mutual_tls"` and a `DestinationRule` that turns off TLS and breaks a `STRICT` destination. Run it with `scripts/ci/test-playground.sh sections/section-040/module-02/playground`.
