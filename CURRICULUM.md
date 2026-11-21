# Curriculum Coverage

> Historical design record. Counts and execution claims below describe the original expansion. For current labs, preparation and practical limits, use [LAB-COVERAGE.md](LAB-COVERAGE.md) and [COVERAGE-REVIEW.md](COVERAGE-REVIEW.md).

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

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. Question banks are separate from the reading manifest and follow their declared summaries.

## Hands-On Coverage

This course has 12 ungraded module playgrounds (8 on kind, 4 on a qemu VM) and 38 graded labs (32 on kind, 6 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`. The Cilium labs and playground in section 040 need Docker or rootful Podman, because Cilium cannot mount `/sys/fs/bpf` under rootless Podman. The qemu VM network plugin does not enforce NetworkPolicy, so the section 030 module 01 playground stays on kind with Calico, and its gVisor reading shows the missing-handler failure. A real gVisor Pod runs in the qemu lab after that reading and in the section 030 module 02 playground.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Enforce Baseline And Restricted With Namespace Labels; Run A Pod That Meets Restricted With A Read-Only Root; Enforce Baseline And Preview Restricted; Repair A Deployment That Pod Security Admission Blocks |
| 010/02 | Run A Deployment As A Non-Root User; Drop All Capabilities And Block Privilege Escalation; Attach A Localhost Seccomp Profile And An AppArmor Profile; Remove Host Networking And A hostPath Volume |
| 010/03 | Roll Out Restricted Using A Dry-Run Inventory; Set Cluster-Wide Pod Security Defaults And An Exemption; Admit A Node Agent And Protect Pod Security Labels |
| 020/01 | Deliver A Secret As An Environment Variable And A File; Rotate A Secret And Refresh Its Consumers; Encrypt Secrets At Rest In etcd |
| 020/02 | Give A ServiceAccount An Image Pull Secret; Create An Immutable Basic-Auth Secret; Limit Secret Access To One Named Secret With RBAC |
| 020/03 | Move A Leaked Credential Into A Secret; Record Secret Access In The Audit Log |
| 030/01 | Limit A Tenant User To One Namespace With RBAC; Cap A Tenant With ResourceQuota And LimitRange; Isolate A Tenant Namespace And Remove Its Token; Run A Pod Under gVisor With A RuntimeClass |
| 030/02 | Register The gVisor Handler In containerd; Schedule Pods With A RuntimeClass Overhead And Node Selector; Require A RuntimeClass With A ValidatingAdmissionPolicy |
| 030/03 | Dedicate A Node To One Tenant With Taints And Tolerations; Use A NodeRestriction Label For Tenant Placement; Require A Tenant Node Selector With A ValidatingAdmissionPolicy |
| 040/01 | Require Mutual TLS With PeerAuthentication; Allow One Workload Identity With AuthorizationPolicy |
| 040/02 | Override Mesh-Wide STRICT For One Namespace; Migrate A Namespace To STRICT With One Exception; Fix A Wrong Principal In An AuthorizationPolicy; Fix A Client TLS Setting That Breaks STRICT |
| 040/03 | Enable WireGuard Encryption In Cilium; Rotate The Cilium IPsec Key; Fix A Cilium Agent That Did Not Load WireGuard |
