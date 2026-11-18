---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Enabling WireGuard

Pod traffic between the nodes of the playground crosses the node network as plain text inside a VXLAN tunnel. WireGuard is the shorter way to encrypt it in Cilium, because the agents create and exchange the keys by themselves. What remains for you is one Helm change, a restart of the agents and a check on each node. This reading does all three in the playground.

## How Cilium sets up WireGuard

WireGuard is a protocol in the Linux kernel that encrypts IP packets between two hosts. It uses a network interface with a key pair, and it sends the encrypted packets as UDP.

When WireGuard is turned on, each Cilium agent creates the interface `cilium_wg0` on its node and generates a key pair. The private key stays on the node. The agent publishes the public key on the CiliumNode object of its node, the Kubernetes object that Cilium keeps for each node. Every other agent reads it and adds the node as a peer. A peer is a remote host whose public key and address the interface knows. When a node joins or leaves, the agents add or remove the peer themselves.

The kernel then sends packets for pods on another node through `cilium_wg0`, which encrypts them and sends them as UDP to port 51871 of the other node. A firewall or cloud security group between the nodes must allow that port, or the peers cannot reach each other.

## The Helm values

Cilium in the playground was installed with Helm, the package manager for Kubernetes, as the release `cilium` in `kube-system`. A release is one installed copy of a chart, and its values are the settings the chart turns into Kubernetes objects. These values control WireGuard:

- `encryption.enabled`: `true` turns transparent encryption on.
- `encryption.type`: `wireguard` or `ipsec`.
- `encryption.nodeEncryption`: `true` also encrypts traffic between the nodes themselves and traffic of pods that use host networking. The default is `false`, which covers pod traffic only.

The values reach the agents through the ConfigMap `cilium-config` in `kube-system`. Each agent reads it when it starts, so a change needs a restart of the DaemonSet.

## Turn it on

Change the release and keep its other values with `--reuse-values`. Without that flag, `helm upgrade` takes the chart defaults for every value you do not set again:

<!-- astrona:playground:renew -->

```sh
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard
```

Helm has now changed `cilium-config`, but the running agents still use the old setting. Restart them and wait until both run again:

```sh
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

The DaemonSet replaces one agent pod at a time. In a test run the restart took about 16 seconds. Open connections can break while the agent on their node restarts, so on a real cluster plan a short change window.

## Check every agent

List the agent pods with their nodes, then ask each one for its encryption state:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

In a test run each agent printed this (the public key is replaced by `...` here):

```text
Encryption: Wireguard
Interface: cilium_wg0
	Public key: ...
	Number of peers: 1
```

The number of peers must equal the number of other nodes. The playground has two nodes, so each agent has one peer. A node with `Number of peers: 0` sends its pod traffic to the other node without WireGuard. The short status `cilium-dbg status | grep Encryption` gives the same facts on one line. In a test run it showed `Encryption: Wireguard [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 1)]`.

The interface itself is in the kernel of the node. The agent container shares the network of the node and has the `ip` tool, so you can look at it from there:

```sh
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- ip -d link show cilium_wg0
```

The first line of the output in a test run was `11: cilium_wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1405`, shortened. The `wireguard` keyword in the details confirms the type. The smaller MTU (maximum transmission unit, the largest packet size) leaves room for the WireGuard header.

## Check the wire

Now repeat the capture on the worker node, this time for both the VXLAN port and the WireGuard port. Start it in a second terminal:

```sh
WORKER_TOOLS=$(kubectl -n node-tools get pod -o name --field-selector spec.nodeName=astro-ats-034-playground-040-03-worker)
kubectl -n node-tools exec $WORKER_TOOLS -- timeout 10 tcpdump -ni eth0 -c 4 'udp port 8472 or udp port 51871'
```

In the first terminal, send a request from `shuttle` to the `probe` pod:

```sh
PROBE_IP=$(kubectl -n starfleet get pod probe -o jsonpath='{.status.podIP}')
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://$PROBE_IP:8080/
```

The reply is still `probe-reply`. In a test run a capture on port 8472 alone saw 0 packets, and a capture on port 51871 showed lines like `IP 10.89.0.3.51871 > 10.89.0.2.51871: UDP, length 144` (timestamp removed). The request now travels between the node addresses as WireGuard packets, and its text is no longer readable on the wire.

You can now turn WireGuard on with Helm, restart the agents and prove the result on every node and on the wire. WireGuard needs a recent kernel, so some clusters must use IPsec instead, and IPsec needs keys that you create and rotate yourself.

## Common pitfalls

> [!WARNING]
> - **Forgetting the restart.** The agents read `cilium-config` only when they start, so they keep reporting `Encryption: Disabled`.
> - **Using `--set` without `--reuse-values`.** Helm resets the other values of the release to the chart defaults.
> - **Blocking UDP 51871 between nodes.** The peers cannot reach each other and cross-node traffic fails.
> - **Checking one agent only.** One node without a peer leaves its own traffic unprotected.
> - **Expecting host-network traffic to be covered.** With `nodeEncryption` off, `NodeEncryption: Disabled` in the status means node traffic stays in plain text.
