---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Use A NodeRestriction Label For Tenant Placement

Move tenant placement from a plain node label, which a kubelet can change on its own node, to a `node-restriction.kubernetes.io/` label that only an administrator can set, and prove the protection with the kubelet's own credentials.

The lab runs in its own pinned two-node kind cluster. The graders read the node labels and the Deployment, and run `kubectl --kubeconfig /etc/kubernetes/kubelet.conf` inside the worker node container (named from `ASTRONA_KIND_CLUSTER` and `ASTRONA_CONTAINER_ENGINE`) to check that the kubelet identity gets Forbidden from the NodeRestriction admission plugin. The kubelet request is a server-side dry run, so grading never changes the node. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
