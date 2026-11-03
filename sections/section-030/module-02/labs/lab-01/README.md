---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Schedule Sandboxed Pods With A RuntimeClass

Create a RuntimeClass with scheduling and overhead, and run a Pod that uses it.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
