# Minimize Microservice Vulnerabilities (ATS034)

Certified Kubernetes Security Specialist (CKS): Minimize Microservice Vulnerabilities, worth 20% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Pod Security Standards And Admission | The Three Pod Security Standards; Security Context Fields; Pod Security Admission Modes; Admission For Workloads And Troubleshooting |
| 020 / 01 | Kubernetes Secrets: Storage, Delivery And Rotation | What A Secret Is And Who Can Read It; Delivering Secrets To Pods; Rotating A Secret; Encryption At Rest |
| 030 / 01 | Tenant Isolation And Sandboxed Containers | Namespaces And RBAC As A Tenant Boundary; Resource Isolation With ResourceQuota And LimitRange; Network Isolation And Token Minimization; Sandboxed Containers With RuntimeClass |
| 040 / 01 | Pod-To-Pod Encryption With Istio And Cilium | Pod Traffic And Encryption Options; Istio Mutual TLS With PeerAuthentication; Authorizing Workloads With AuthorizationPolicy; Cilium Transparent Encryption |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). No runtime execution is claimed.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Enforce Restricted Pod Admission |
| 020/01 | Rotate A Secret And Refresh Its Consumer |
| 030/01 | Compose A Tenant Namespace Boundary |
| 040/01 | Require Mutual TLS Between Workloads |

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.
