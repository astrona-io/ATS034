# Reusable Question Banks

`assessments/index.yaml` lists banks in teaching order. Each bank uses schema
version 1 and the contract in `schemas/question-bank.schema.json`. This is an
authoring format for future application integration, not an existing Astrona
quiz API. No YAML question file is registered as a Markdown reading.

Banks follow their declared module summaries. Larger domains use an intermediate
checkpoint after the third section and a final domain review; smaller domains
use a final domain review. The index records covered sections and teaching order. Banks contain 5–15 original single-choice
questions, scoped to concepts taught in the course. They remain draft for review.

## Fields And Rendering

- `id`: stable bank or question identity; preserve it when editing wording.
- `scope`: section or domain checkpoint.
- `placement`: relative reading path after which the checkpoint belongs.
- `learning_objective`: the measurable outcome checked by the question.
- `source_readings`: author traceability to the teaching; not learner navigation.
- `prompt`: learner-visible question text.
- `options`: stable option IDs, answer text and per-option feedback.
- `correct_option`: the ID of the single correct option.
- `explanation`: feedback reinforcing the supported answer.

The application should send only the question ID, prompt and option IDs/text to
the learner before submission. Keep `correct_option`, `explanation` and option
explanations on the server until feedback is permitted. Match answers by option
ID, not display position, so a later renderer can shuffle choices safely.

The banks contain answer keys and are public learning material, so this is not
a secure examination bank. Do not treat scores as an official CKS result.

## Hands-On Coverage

This course has 12 ungraded module playgrounds (8 on kind, 4 on a qemu VM) and 39 graded labs (32 on kind, 7 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`. The Cilium labs and playground in section 040 need Docker or rootful Podman, because Cilium cannot mount `/sys/fs/bpf` under rootless Podman. The qemu VM network plugin does not enforce NetworkPolicy, so the section 030 module 01 playground stays on kind with Calico, and its gVisor reading shows the missing-handler failure. A real gVisor Pod runs in the qemu lab after that reading and in the section 030 module 02 playground.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Enforce Baseline And Restricted With Namespace Labels; Run A Pod That Meets Restricted With A Read-Only Root; Enforce Baseline And Preview Restricted; Repair A Deployment That Pod Security Admission Blocks |
| 010/02 | Run A Deployment As A Non-Root User; Drop All Capabilities And Block Privilege Escalation; Attach A Localhost Seccomp Profile And An AppArmor Profile; Remove Host Networking And A hostPath Volume |
| 010/03 | Roll Out Restricted Using A Dry-Run Inventory; Set Cluster-Wide Pod Security Defaults And An Exemption; Admit A Node Agent And Protect Pod Security Labels |
| 020/01 | Deliver A Secret As An Environment Variable And A File; Rotate A Secret And Refresh Its Consumers; Encrypt Secrets At Rest In etcd; Rotate The Encryption-At-Rest Key |
| 020/02 | Give A ServiceAccount An Image Pull Secret; Create An Immutable Basic-Auth Secret; Limit Secret Access To One Named Secret With RBAC |
| 020/03 | Move A Leaked Credential Into A Secret; Record Secret Access In The Audit Log |
| 030/01 | Limit A Tenant User To One Namespace With RBAC; Cap A Tenant With ResourceQuota And LimitRange; Isolate A Tenant Namespace And Remove Its Token; Run A Pod Under gVisor With A RuntimeClass |
| 030/02 | Register The gVisor Handler In containerd; Schedule Pods With A RuntimeClass Overhead And Node Selector; Require A RuntimeClass With A ValidatingAdmissionPolicy |
| 030/03 | Dedicate A Node To One Tenant With Taints And Tolerations; Use A NodeRestriction Label For Tenant Placement; Require A Tenant Node Selector With A ValidatingAdmissionPolicy |
| 040/01 | Require Mutual TLS With PeerAuthentication; Allow One Workload Identity With AuthorizationPolicy |
| 040/02 | Override Mesh-Wide STRICT For One Namespace; Migrate A Namespace To STRICT With One Exception; Fix A Wrong Principal In An AuthorizationPolicy; Fix A Client TLS Setting That Breaks STRICT |
| 040/03 | Enable WireGuard Encryption In Cilium; Rotate The Cilium IPsec Key; Fix A Cilium Agent That Did Not Load WireGuard |
