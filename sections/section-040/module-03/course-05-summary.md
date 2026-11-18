---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Summary

Cilium encrypts pod traffic in the Linux kernel, between nodes, with no change to the applications and no sidecar. The kernel of the sending node encrypts the packet and the kernel of the receiving node decrypts it. Traffic between pods on one node and traffic that leaves the cluster are outside the scope, and the encryption does not identify the sending pod. Before encryption, a capture of the VXLAN tunnel on UDP port 8472 shows the HTTP request between pods as readable text.

Cilium offers two protocols, and a cluster uses one at a time. WireGuard needs the WireGuard module in the kernel. Each agent creates the interface `cilium_wg0`, generates its own key pair, adds every other node as a peer and sends the encrypted packets as UDP to port 51871. IPsec works on more kernels, sends ESP packets and needs a key that you create and rotate.

The Helm release `cilium` in `kube-system` holds the settings: `encryption.enabled`, `encryption.type` and, for host-network traffic, `encryption.nodeEncryption`. A change uses `helm upgrade --reuse-values`, so the other values stay, and then a restart of the DaemonSet `cilium`, because the agents read the setting only when they start.

The IPsec key lives in the Secret `cilium-ipsec-keys` in `kube-system`, under the data key `keys`. Its value is one line: an SPI with a plus sign, the algorithm `rfc4106(gcm(aes))`, a key of 40 hexadecimal characters and the length `128`. A rotation writes a new key with a higher SPI into the same Secret. The agents load it without a restart after a random wait of up to 30 seconds, keep the old key for a few minutes and then remove it.

Verification goes from the agent to the wire, on every node:

- `cilium-dbg encrypt status` names the protocol, the WireGuard peers or the IPsec keys in use and the error count.
- `ip -d link show cilium_wg0` and `ip xfrm state`, filtered to the SPI, show the state in the kernel of the node.
- A capture on the node interface shows UDP 51871 or ESP packets between the node addresses and no readable request text.

A report names what is not covered, and it pairs Cilium, for encryption of all traffic between nodes, with Istio, for workload identity and authorization.

<!-- astrona:playground:destroy -->
