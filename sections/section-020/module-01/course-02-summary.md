---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Summary

Secrets separate sensitive configuration from image artifacts but still need access controls, storage protection and safe consumer behavior. Base64 representation is encoding, while encryption and authorization protect different boundaries.

Environment variables and mounted files adopt updates differently. Rotation must coordinate issuers and consumers, revoke old authority where intended and verify behavior without printing sensitive values. A current source value is not proof that every running process uses it.

You can now describe safe credential verification without using disclosure as evidence. Each rotation plan must state how consumers adopt updates and when old authority is removed.
