---
draft: true
exam_objectives:
- Manage Kubernetes secrets
---
# Manage Kubernetes secrets

A database stops accepting its old password before every consumer adopts the replacement. The Secret update succeeded, yet requests fail. Credential rotation must coordinate the issuer, stored value, delivery method and running consumers.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Each module has a playground for practice and a graded lab, and the section ends with a capstone lab.

Read the module goals, teaching and closing summary in order. The section has three modules. The first covers how a Secret is stored, delivered to Pods and rotated. The second covers Secret types, image pull credentials, immutable Secrets and least-privilege access. The third covers where credentials leak, external secret stores, encrypting Secrets for Git and auditing Secret access. A knowledge check follows each module summary, and a capstone lab at the end combines the skills.

## Learning Outcomes

- Explain why Secret encoding is not encryption.
- Compare environment and mounted-file update behavior.
- Identify authorization and diagnostic exposure risks.
- Describe rotation that updates consumers and revokes old authority.
- Choose the Secret type for a login, a TLS key pair and a registry credential.
- Create an immutable Secret and roll out a new value with a new name.
- Write a Role that reads one named Secret and check it with `kubectl auth can-i`.
- Find credentials in ConfigMaps, manifests, annotations, images and logs, and move them into Secrets.
- Compare external secret stores, Sealed Secrets and SOPS, and state what each leaves exposed.
- Write an audit policy that records Secret access without recording values.
