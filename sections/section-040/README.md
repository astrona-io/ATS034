---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Implement Pod-to-Pod encryption (Cilium, Istio)

Pod traffic in a Kubernetes cluster is plain text unless you add encryption. A proxy or a network plugin can encrypt a connection to another workload, but that alone does not decide which workload may call which application operation. Transport encryption, peer authentication and authorization answer different questions, and this section teaches them in order.

The section has three modules and a capstone. The first module compares the ways to encrypt Pod traffic, enables strict mutual TLS in Istio, authorizes callers with an `AuthorizationPolicy` and explains Cilium transparent encryption. The second module covers the operation of Istio mutual TLS: the modes and scopes of a `PeerAuthentication`, a safe migration from `PERMISSIVE` to `STRICT`, the certificates and identities that `istiod` issues, and the checks that prove a connection is encrypted. The third module covers Cilium encryption in depth: what it protects, how to enable WireGuard, how to manage IPsec keys, and how to verify the result on the agent, the node and the wire. The capstone combines a strict namespace, an identity-based authorization rule and the Cilium values in one graded task.

Each module has a playground, a graded lab and a quiz. The Cilium module has no Cilium cluster to run, so its lab grades the Helm values and the key Secret that a Cilium installation reads.

## Learning Outcomes

- Distinguish encrypted transport, peer authentication and authorization.
- Explain where mesh components implement communication policy.
- Choose the scope of a `PeerAuthentication` and migrate a namespace from `PERMISSIVE` to `STRICT` with narrow exceptions.
- Relate certificate rotation and workload identity to trust.
- Enable Cilium WireGuard or IPsec encryption, rotate IPsec keys and verify the result.
- Identify what encryption does not cover: same-node traffic, external traffic and the identity of the sender.
