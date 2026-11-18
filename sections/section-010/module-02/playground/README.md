# Harden Container Privileges Playground

This ungraded `kind` cluster (Kubernetes v1.35, one control-plane node and one worker) is the playground for this module. It has a private context, `kind-astro-ats-034-playground-010-02`, and a pinned node image. `bootstrap/setup.sh` creates the starting namespaces and workloads, and `docs/overview.md` is the guide the learner sees.

`testing/smoke.sh` runs the commands the guide teaches and fails when one of them does not give the expected result. Run the whole check with `scripts/ci/test-playground.sh sections/section-010/module-02/playground`; it starts the playground, runs the smoke test and always destroys the playground. The configuration has no submission or grading fields.
