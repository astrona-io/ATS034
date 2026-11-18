# Secret Types, Immutability And Access Playground

This ungraded playground is a pinned kind cluster (one control plane, one worker). `bootstrap/setup.sh` creates the `starfleet` namespace with the `probe` Deployment and Service, the `shuttle` pod and the Secret `practice-token`, and the `outpost` namespace with the `drifter` pod. The configuration has no submission or grading fields.

`testing/smoke.sh` runs the commands of the guided practice: it creates an immutable `kubernetes.io/basic-auth` Secret, reads it from a pod, checks that a patch is rejected with an `immutable` error and that the `default` ServiceAccount cannot list Secrets, then removes what it created. Run it with `scripts/ci/test-playground.sh sections/section-020/module-02/playground`.
