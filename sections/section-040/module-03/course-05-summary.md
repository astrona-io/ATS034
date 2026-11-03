---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Summary

Cilium encrypts Pod traffic in the kernel, between nodes, with no change to the applications and no sidecar. The sending node encrypts the packet and the receiving node decrypts it. Traffic between Pods on one node and traffic that leaves the cluster is outside the scope, and the encryption does not identify the sending workload.

Cilium offers two protocols. WireGuard needs a kernel of version 5.6 or newer, creates the interface `cilium_wg0` on each node, shares public keys through node annotations and uses UDP port 51871. IPsec works on kernels without WireGuard, uses ESP packets and needs keys that you create and rotate. WireGuard is the shorter path when the kernels allow it.

The Helm values select the protocol: `encryption.enabled`, `encryption.type`, and for WireGuard `encryption.nodeEncryption` and, in recent versions, `encryption.strictMode`. For IPsec the values name a Secret, by default `cilium-ipsec-keys` in `kube-system`, whose data key `keys` holds a line with a SPI, the algorithm `rfc4106(gcm(aes))`, a key of 40 hexadecimal characters and the length `128`. A rotation replaces the line with a new key and a higher SPI. The agents read the settings when they start, so a rollout restarts the DaemonSet.

Verification goes from the agent to the wire. `cilium-dbg status` and `cilium-dbg encrypt status` show the state of each agent, the node shows the WireGuard interface or the IPsec security associations, and a packet capture shows UDP packets on port 51871 or ESP packets without readable text. A report names what is not covered, and it combines Cilium for coverage of all nodes with Istio for identity and authorization.

<!-- astrona:playground:destroy -->
