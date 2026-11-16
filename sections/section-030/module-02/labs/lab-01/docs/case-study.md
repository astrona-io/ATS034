---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers,
  etc.)
---
# Starting Environment

The isolated environment has an empty namespace `tenant-b-034-030-02-01` and two nodes. The worker node has no sandbox label, and no RuntimeClass exists for sandboxed Pods.

Create a RuntimeClass with scheduling and overhead, and run a Pod that uses it.
