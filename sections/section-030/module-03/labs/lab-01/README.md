---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Dedicate A Node To One Tenant

Reserve the worker node for one tenant with a label, a taint, a selector and a toleration.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
