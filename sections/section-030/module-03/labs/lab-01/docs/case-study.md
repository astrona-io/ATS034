---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Starting Environment

The isolated environment has an empty namespace `tenant-c` and two nodes. The worker node has no tenant label and no taint.

Reserve the worker node for one tenant with a label, a taint, a selector and a toleration.
