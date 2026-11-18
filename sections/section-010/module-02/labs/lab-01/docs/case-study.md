---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The namespace `starfleet-034-010-02-01` has no Pod Security labels. It runs the Deployment `probe` with two replicas of a small Python HTTP server, the Service `probe` on port 80, and the client Pod `shuttle`. The `probe` image declares no user, so its process runs as user ID 0 (root).
