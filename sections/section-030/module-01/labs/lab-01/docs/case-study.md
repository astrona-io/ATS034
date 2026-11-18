---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Starting Environment

The namespaces `tenant-a-034-030-01-01` and `tenant-b-034-030-01-01` exist, and each one holds a Secret named `api-key`. The ClusterRoleBinding `alice-edit` binds the built-in ClusterRole `edit` to the user `alice` in every namespace. You act as the cluster administrator.
