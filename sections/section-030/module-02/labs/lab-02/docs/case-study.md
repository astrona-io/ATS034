---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The cluster has two nodes: `astro-ats-034-lab-030-02-02-control-plane` and `astro-ats-034-lab-030-02-02-worker`. The namespace `tenant-b-034-030-02-02` is empty. No RuntimeClass exists, and no node has a `sandbox` label. The only container runtime handler of this kind cluster is `runc`, so the RuntimeClass of the task uses `runc` and practises the overhead and scheduling fields, not a gVisor or Kata Containers sandbox.
