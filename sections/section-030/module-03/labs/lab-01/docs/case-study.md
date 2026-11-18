---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The cluster has two nodes: `astro-ats-034-lab-030-03-01-control-plane` and `astro-ats-034-lab-030-03-01-worker`. The namespaces `tenant-c-034-030-03-01` and `outpost-034-030-03-01` are empty. The worker node has no `tenant` label and no `tenant` taint. The control-plane node keeps its usual `node-role.kubernetes.io/control-plane:NoSchedule` taint.
