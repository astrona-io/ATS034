---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `starfleet-034-010-02-04` enforces the Baseline profile, pinned to version `v1.35`. It holds the Deployment `collector` with one replica. Its Pod template uses the network namespace of the node and mounts the node directory `/var/log` as the volume `logs` at `/logs`. Pod Security Admission rejects every Pod that the ReplicaSet tries to create.
