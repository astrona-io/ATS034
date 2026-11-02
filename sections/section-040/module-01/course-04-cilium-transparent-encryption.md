---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Cilium Transparent Encryption

Cilium is a CNI plugin. It can encrypt the traffic between nodes without any change to the Pods. This part is a reference procedure. The playground runs a different CNI plugin, so the commands here are for a cluster that has Cilium installed, and you do not run them in the playground.

## What transparent encryption covers

Cilium encrypts packets that leave a node for a Pod on another node. The sending node encrypts the packet and the receiving node decrypts it. The applications use plain TCP or UDP and do not know. Traffic between two Pods on the same node does not cross the network, so it is not encrypted. Traffic from a Pod to the outside of the cluster is not covered either.

Cilium supports two encryption protocols:

- **WireGuard.** Cilium creates a WireGuard interface called `cilium_wg0` on each node, and each node has a public key that Cilium shares with the other nodes through a node annotation. It needs a Linux kernel with WireGuard support and uses UDP port 51871 between nodes.
- **IPsec.** Cilium uses the kernel IPsec stack with keys that you store in a Kubernetes Secret. It works on kernels without WireGuard, and you must rotate the keys yourself. It uses ESP packets (IP protocol 50) and, for some modes, UDP port 4500.

Both protocols protect traffic between nodes. Neither identifies the sending workload to the receiver, which is the difference from Istio mTLS.

## Enable WireGuard with Helm

Cilium is configured through Helm values. These are the values for WireGuard:

```sh
helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
kubectl -n kube-system rollout restart daemonset/cilium
```

The restart makes the agents on every node start with encryption. Firewalls between nodes must allow UDP 51871. For IPsec, set `encryption.type=ipsec`, create the key Secret first and point the chart at it with `encryption.ipsec.secretName`. An existing connection is not guaranteed to move to the encrypted path at the moment of the change, so plan a short window for the rollout.

## Verify that it is active

Ask an agent for its encryption state:

```sh
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep -i encryption
```

The line begins with `Encryption:` and names the mode, for example WireGuard, and the number of peers. With WireGuard you can also list the interface on a node:

```sh
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
```

The output lists the WireGuard interface and its peers. A peer that is missing means that traffic to that node is not encrypted. For proof at the wire, capture packets on the node's network interface with `tcpdump` while two Pods on different nodes talk. An encrypted path shows UDP packets on the WireGuard port and no readable HTTP text.

## Cilium compared with Istio

| Question | Cilium encryption | Istio mTLS |
| --- | --- | --- |
| Where it runs | The node, in the kernel | The sidecar in each Pod |
| Application change | None | None, but a sidecar is added |
| Caller identity | None | SPIFFE ID from the ServiceAccount |
| Same-node traffic | Not encrypted | Encrypted when both Pods are meshed |
| Protocols | All IP traffic between nodes | TCP connections of meshed Pods |
| Authorization | Use NetworkPolicy | AuthorizationPolicy by principal |

The two can run together. Cilium protects every packet between nodes, including traffic from Pods that have no sidecar. Istio adds identity and authorization for the Pods in the mesh.

## Common pitfalls

> [!WARNING]
> - **Assuming same-node traffic is encrypted.** Packets between Pods on one node never leave it, and Cilium does not encrypt them.
> - **Blocking the tunnel port.** A firewall that drops UDP 51871 for WireGuard breaks cross-node traffic or leaves it unprotected, depending on the setup.
> - **Running WireGuard on an unsupported kernel.** The agent cannot create the interface, so check the kernel before the rollout.
> - **Not rotating IPsec keys.** The keys live in a Secret and do not rotate on their own.
> - **Skipping the verification.** Enabling a Helm value does not prove that the traffic is encrypted. Check `cilium-dbg status`.
