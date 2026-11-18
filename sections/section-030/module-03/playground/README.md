# Node Separation Playground

Ungraded `kind` playground for section 030, module 03. It runs a pinned two-node Kubernetes 1.35 cluster and seeds the empty namespace `tenant-c`.

`testing/smoke.sh` takes the YAML blocks straight from the module pages and runs the page commands (label and taint, tolerated Deployment, Pending stray Pod, NodeRestriction flags, protected label, `can-i`, ValidatingAdmissionPolicy denial). It fails when a result differs from what the page says. Run it with `scripts/ci/test-playground.sh sections/section-030/module-03/playground`.
