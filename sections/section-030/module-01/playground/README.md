# Tenant Isolation Playground

Ungraded `kind` playground for section 030, module 01. It runs a pinned two-node Kubernetes 1.35 cluster with Calico and seeds the `starfleet` (`probe` Deployment and Service, `shuttle` client) and `outpost` (`drifter` client) namespaces.

`testing/smoke.sh` takes the YAML blocks straight from the module pages and runs the page commands (RBAC `can-i`, quota and LimitRange, NetworkPolicy, token mount, RuntimeClass without a handler). It fails when a result differs from what the page says. Run it with `scripts/ci/test-playground.sh sections/section-030/module-01/playground`.
