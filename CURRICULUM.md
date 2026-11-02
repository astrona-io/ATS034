# Curriculum Coverage

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Minimize Microservice Vulnerabilities (20%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Use appropriate pod security standards | 1 |
| 020 | Manage Kubernetes secrets | 1 |
| 030 | Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.) | 1 |
| 040 | Implement Pod-to-Pod encryption (Cilium, Istio) | 1 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Pod Security Profiles | Security Contexts And Profile Requirements; Applying Pod Security Requirements At Admission |
| 020 / 01 | Secret Delivery And Credential Lifecycle | Secret Storage, Delivery And Rotation |
| 030 / 01 | Choosing Isolation For Untrusted Tenants | Choosing Isolation For Untrusted Tenants |
| 040 / 01 | Service Mesh Identity And Policy | Transport Protection And Mesh Limits; Transparent Encryption And Its Traffic Boundaries |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. No labs, playgrounds or runtime validation are included.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Enforce Restricted Pod Admission |
| 020/01 | Rotate A Secret And Refresh Its Consumer |
| 030/01 | Compose A Tenant Namespace Boundary |
| 040/01 | Require Mutual TLS Between Workloads |
