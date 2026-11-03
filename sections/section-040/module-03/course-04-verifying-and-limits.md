---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Verifying Cilium Encryption And Its Limits

A Helm value and a running agent are not proof that packets are encrypted. This part is a reference procedure for a cluster that runs Cilium. The playground does not run Cilium, so you do not run these commands there. They teach the order of checks, from the agent to the wire, and the limits you must state when you report the result.

## Check the agent

Start with the agent on one node. The Cilium agent runs as the DaemonSet `cilium` in `kube-system`, and `cilium-dbg` is the command-line tool inside it:

```sh
kubectl -n kube-system exec ds/cilium -- cilium-dbg status | grep -i encryption
kubectl -n kube-system exec ds/cilium -- cilium-dbg encrypt status
```

The first command prints the line that begins with `Encryption:`. It names the protocol, and for WireGuard it names the interface, the port and the number of peers. A value of `Disabled` means the agent did not load the setting, usually because it was not restarted. The second command prints details of the encryption state. For WireGuard the number of peers must equal the number of other nodes, and a missing peer means traffic to that node is not encrypted. For IPsec, the output shows the key identifier in use, which must match the SPI of the Secret.

The command with `ds/cilium` runs against one agent. Repeat it for each node, because one broken node leaves only its own traffic unprotected:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
```

The list shows which agent runs on which node, so you can run the check on each.

## Check the node

The next layer is the kernel of the node. For WireGuard, look at the interface that Cilium created. For IPsec, look at the kernel's security associations. Run these on the node itself, with root rights:

```sh
ip -d link show cilium_wg0
ip xfrm state
```

The first command shows the WireGuard interface, and it fails with an error when the interface does not exist. The second prints the IPsec security associations, one for each peer and direction, and it prints nothing for a cluster without IPsec.

## Check the wire

The strongest proof is a packet capture on the physical network interface of a node while two Pods on different nodes talk. Start an HTTP request between the Pods, and capture with `tcpdump`:

```sh
tcpdump -n -i any udp port 51871 -c 10
tcpdump -n -i any esp -c 10
```

The first command is for WireGuard. It shows UDP packets between the node addresses on port 51871. The second is for IPsec. It shows ESP packets between the node addresses. In both cases a capture filtered on the HTTP port of the application on the same interface shows no readable request text. If the capture shows plain HTTP between the nodes, the traffic is not encrypted.

## Diagnose a problem

| Symptom | Likely cause | Check |
| --- | --- | --- |
| `Encryption: Disabled` on an agent | The agent did not restart after the change | Restart the DaemonSet and read the status again |
| A WireGuard peer is missing | UDP 51871 is blocked, or the node has no public-key annotation | Test the port between nodes |
| The agent fails to start with encryption on | The kernel has no WireGuard, or the Secret is missing | Read the agent log with `kubectl logs` |
| Cross-node traffic is dropped | The IPsec keys differ between nodes | Compare the SPI on all nodes |
| Throughput is lower | Encryption uses CPU and adds a header to each packet | Measure before and after |

## State the limits

When you report that Pod traffic is encrypted, say what you did not cover. Cilium encryption protects traffic between nodes. It does not protect traffic between two Pods on one node, and it does not protect traffic that leaves the cluster. It does not identify the sender, so it does not replace a network policy or an Istio `AuthorizationPolicy`. It does not protect against a compromised node, because the node holds the keys.

Cilium and Istio work together. Cilium encryption covers every packet between nodes, including Pods without a sidecar. Istio mTLS adds the workload identity and the rules by principal for the Pods in the mesh. Traffic of meshed Pods is then encrypted twice, which costs extra CPU, and some clusters accept that cost for the layered result.

## Common pitfalls

> [!WARNING]
> - **Checking one agent only.** One node with a missing peer or old keys leaves its traffic unprotected.
> - **Reading old connections.** A connection opened before the rollout may not use the new path.
> - **Capturing on the Pod interface.** Inside the node the packets are already decrypted. Capture on the node interface.
> - **Reporting full coverage.** Same-node and external traffic are outside the scope.
> - **Mixing up encryption and authorization.** Encryption does not say which workload sent the packet.
