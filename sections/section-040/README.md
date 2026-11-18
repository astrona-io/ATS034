---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Implement Pod-to-Pod encryption (Cilium, Istio)

Pod traffic in a Kubernetes cluster is plain text unless you add encryption. A proxy or a network plugin can encrypt a connection to another workload, but that alone does not decide which workload may call which application operation. Transport encryption, peer authentication and authorization answer different questions, and this section teaches them in order.

The section has three modules. The first module compares the ways to encrypt Pod traffic, enables strict mutual TLS in Istio, authorizes callers with an `AuthorizationPolicy` and explains Cilium transparent encryption. The second module covers the operation of Istio mutual TLS: the modes and scopes of a `PeerAuthentication`, a safe migration from `PERMISSIVE` to `STRICT`, the certificates and identities that `istiod` issues, and the checks that prove a connection is encrypted. The third module covers Cilium encryption in depth: what it protects, how to enable WireGuard, how to switch to IPsec and rotate its key, and how to verify the result on the agent, the node and the wire.

Each module has a playground, graded labs right after the readings they practise, and a quiz. The Istio modules run Istio 1.30.5 on a kind cluster. The Cilium module runs Cilium 1.20.4 as the network plugin of its kind cluster, so it needs Docker or rootful Podman; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`.

## Learning Outcomes

- Distinguish encrypted transport, peer authentication and authorization.
- Explain where mesh components implement communication policy.
- Choose the scope of a `PeerAuthentication` and migrate a namespace from `PERMISSIVE` to `STRICT` with narrow exceptions.
- Relate certificate rotation and workload identity to trust.
- Enable Cilium WireGuard or IPsec encryption, rotate IPsec keys and verify the result.
- Identify what encryption does not cover: same-node traffic, external traffic and the identity of the sender.
