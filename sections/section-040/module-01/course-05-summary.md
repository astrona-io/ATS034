---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Summary

Pod traffic in a Kubernetes cluster is plain text unless you add encryption. The network plugin moves packets and does not protect them, so an observer on a node or on the network between nodes can read requests and responses.

Three approaches add protection. Application TLS works in each service and needs code and certificates. Istio mTLS works in a sidecar proxy, encrypts the connection, and gives each workload an identity from its ServiceAccount. Cilium transparent encryption works in the kernel of each node, uses WireGuard or IPsec, and protects traffic between nodes with no identity for the sender.

Istio starts in permissive mode, where meshed workloads accept both mTLS and plain text. A `PeerAuthentication` with `mtls.mode: STRICT` makes the receiving sidecar accept only mTLS and close plain-text connections. Its scope comes from its namespace and selector, and the most specific policy wins. Clients without a sidecar fail under strict mode, so inject sidecars first, then enforce.

An `AuthorizationPolicy` uses the principal from the mTLS certificate. The first `ALLOW` policy for a workload turns the default into deny. A `DENY` policy is evaluated before `ALLOW`. Principal rules need STRICT mTLS, because plain-text callers have no principal. The policy is enforced by sidecars only.

Cilium encryption does not cover traffic between Pods on the same node or traffic that leaves the cluster. WireGuard needs kernel support and a reachable UDP port. IPsec needs keys in a Secret that you rotate. Verify the setting with the Cilium agent status and, when proof is needed, with a packet capture.

<!-- astrona:playground:destroy -->
