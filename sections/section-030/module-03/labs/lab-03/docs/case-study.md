---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The cluster has two nodes: `astro-ats-034-lab-030-03-03-control-plane` and `astro-ats-034-lab-030-03-03-worker`. The worker node has the label `node-restriction.kubernetes.io/tenant=tenant-e`. The namespaces `tenant-e-034-030-03-03` and `starfleet-034-030-03-03` exist. The Deployment `tenant-e-app` in `tenant-e-034-030-03-03` runs one Pod with the image `docker.io/library/busybox:1.37.0` and no node selector. No ValidatingAdmissionPolicy exists.
