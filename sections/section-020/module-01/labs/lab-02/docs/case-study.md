---
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The namespace `starfleet-034-020-01-02` holds the Secret `practice-token`. Its key `token` holds the disposable value `disposable-v1`. The pod `file-reader` mounts the Secret as a volume at `/credentials`. The pod `env-reader` reads the key `token` into the environment variable `PRACTICE_TOKEN`. The ConfigMap `rotation-start` records the UID of both starting pods.
