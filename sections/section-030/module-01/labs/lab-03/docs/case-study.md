---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The cluster uses Calico, a network plugin that enforces NetworkPolicy. The namespace `starfleet-034-030-01-03` runs the Deployment `probe` (two replicas, label `app: probe`, TCP port 8080), the Service `probe` on port 80, the Pod `beacon` (label `app: beacon`, TCP port 8080) and the client Pod `shuttle`. The namespace `tenant-a-034-030-01-03` has the ServiceAccount `worker` and the Pod `worker`, which uses that ServiceAccount and runs the image `docker.io/library/busybox:1.37.0` with the command `sleep infinity`. No NetworkPolicy exists.
