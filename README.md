<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS034.svg" alt="ATS034: Minimize Microservice Vulnerabilities, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Minimize Microservice Vulnerabilities (ATS034)

Certified Kubernetes Security Specialist (CKS): Minimize Microservice Vulnerabilities, worth 20% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Private playgrounds and graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Pod Security Standards And Admission | The Three Pod Security Standards; Security Context Fields; Pod Security Admission Modes; Admission For Workloads And Troubleshooting |
| 020 / 01 | Kubernetes Secrets: Storage, Delivery And Rotation | What A Secret Is And Who Can Read It; Delivering Secrets To Pods; Rotating A Secret; Encryption At Rest |
| 030 / 01 | Tenant Isolation And Sandboxed Containers | Namespaces And RBAC As A Tenant Boundary; Resource Isolation With ResourceQuota And LimitRange; Network Isolation And Token Minimization; Sandboxed Containers With RuntimeClass |
| 040 / 01 | Pod-To-Pod Encryption With Istio And Cilium | Pod Traffic And Encryption Options; Istio Mutual TLS With PeerAuthentication; Authorizing Workloads With AuthorizationPolicy; Cilium Transparent Encryption |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). Runtime results are recorded in the PR and GitHub Actions.

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

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.

See [lesson and lab links](LAB-COVERAGE.md) and [remaining practical gaps](COVERAGE-REVIEW.md) for the current assessment scope.
