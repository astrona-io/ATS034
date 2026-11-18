---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Schedule Pods With A RuntimeClass Overhead And Node Selector

Create a RuntimeClass with a fixed Pod overhead and a scheduling node selector, label the worker node and run a Pod that uses the class.

The lab runs in its own pinned two-node kind cluster. The only runtime handler there is `runc`, and the task says so plainly: the lab practises the RuntimeClass admission and scheduling fields, not a real sandbox. The graders read the RuntimeClass and the node labels, send a server-side dry-run Pod to prove that the API server adds the overhead and the node selector, and check that `sandboxed-app` runs Ready on the worker. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
