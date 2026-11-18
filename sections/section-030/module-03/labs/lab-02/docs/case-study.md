---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The cluster has two nodes: `astro-ats-034-lab-030-03-02-control-plane` and `astro-ats-034-lab-030-03-02-worker`. The worker node has the plain label `tenant=tenant-d`. The Deployment `tenant-d-app` in `tenant-d-034-030-03-02` runs one Pod with the node selector `tenant: tenant-d`. The API server runs the NodeRestriction admission plugin, and the kubelet of the worker uses the kubeconfig `/etc/kubernetes/kubelet.conf` on the worker node.
