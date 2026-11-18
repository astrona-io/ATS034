---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# What Cilium Encrypts

Before you turn on encryption, you must know exactly which packets it covers. An administrator who reports "all pod traffic is encrypted" and is wrong gives the team a false sense of security. This reading defines the scope of Cilium transparent encryption, compares its two protocols and then shows, in the playground, that pod traffic between nodes is plain text today.

## Where the encryption happens

Cilium runs an agent on every node, as the DaemonSet `cilium` in `kube-system`. The agent loads eBPF programs into the kernel and sets up the network for the pods on that node. With encryption on, a packet from a pod on node A to a pod on node B is encrypted by the kernel of node A just before it leaves the node. The kernel of node B decrypts it when it arrives. The pods send plain TCP and UDP and do not take part, so this is called transparent encryption.

Only the path between the two kernels is protected. That gives these rules:

- Traffic between pods on different nodes is encrypted.
- Traffic between two pods on the same node never leaves the node, so Cilium does not encrypt it.
- Traffic from a pod to a destination outside the cluster is not covered.
- Traffic of pods that use host networking is node traffic. WireGuard covers it only when node encryption is also turned on.

Encryption also does not tell the receiver which pod sent a packet. That job stays with a network policy or with a service mesh such as Istio.

```mermaid
flowchart LR
  A["shuttle pod"] -->|"plain"| B["kernel: control plane"]
  B -->|"encrypted"| C["kernel: worker"]
  C -->|"plain"| D["probe pod"]
```

The diagram shows that only the hop between the two node kernels is encrypted.

## WireGuard and IPsec

Cilium offers two protocols. They protect the same packets, but they differ in how keys are made and in what you see on the node.

| Question | WireGuard | IPsec |
| --- | --- | --- |
| Keys | Each agent creates a key pair and publishes its public key | You create one key in a Kubernetes Secret and rotate it yourself |
| Kernel | Needs WireGuard in the kernel (Linux 5.6 and newer) | Needs the kernel IPsec stack, which most kernels include |
| On the wire | UDP port 51871 between nodes | ESP packets (Encapsulating Security Payload, IP protocol 50) |
| On the node | The interface `cilium_wg0` | Security associations in the kernel, shown by `ip xfrm state` |

Choose WireGuard when every node supports it, because Cilium manages the keys. Choose IPsec when a kernel is too old for WireGuard or when a rule requires IPsec algorithms. A cluster uses one protocol at a time.

## See the plain text first

The playground places the `probe` pod on the worker node and the `shuttle` pod on the control-plane node, so their traffic crosses between nodes. Check where each pod runs:

<!-- astrona:playground:renew -->

```sh
kubectl get pods -n starfleet -o wide
kubectl get pods -n node-tools -o wide
```

In a test run the output showed `probe` with the address `10.244.1.91` on the worker node and `shuttle` with `10.244.0.70` on the control-plane node. The two `node-tools` pods use host networking, so their addresses are the node addresses `10.89.0.2` and `10.89.0.3`. Your addresses can differ.

Now ask each Cilium agent for its encryption state. `cilium-dbg` is the command-line tool inside the `cilium-agent` container. List the agent pods first, then run the status command in each one:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent reports `Encryption: Disabled`. Pods on different nodes reach each other through a VXLAN tunnel: the sending node wraps the pod packet in a UDP packet on port 8472. VXLAN (Virtual Extensible LAN) only wraps the packet; it does not encrypt it.

To see this on the wire, capture on the worker node while `shuttle` sends a request. Open a second terminal with the same `KUBECONFIG` and start the capture in the `node-tools` pod of the worker node:

```sh
WORKER_TOOLS=$(kubectl -n node-tools get pod -o name --field-selector spec.nodeName=astro-ats-034-playground-040-03-worker)
kubectl -n node-tools exec $WORKER_TOOLS -- timeout 10 tcpdump -ni eth0 -c 4 -A udp port 8472
```

In the first terminal, send one request from `shuttle` to the `probe` pod address:

```sh
PROBE_IP=$(kubectl -n starfleet get pod probe -o jsonpath='{.status.podIP}')
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://$PROBE_IP:8080/
```

The request prints `probe-reply`. The capture shows the tunnel packets, and the last one carries the request in readable text. This is the last packet of a test run, shortened:

```text
11:04:09.737936 IP 10.89.0.2.44797 > 10.89.0.3.8472: OTV, flags [I] (0x08), overlay 0, instance 25555
IP 10.244.0.70.50068 > 10.244.1.91.8080: Flags [P.], seq 1:80, ack 1, win 64, options [nop,nop,TS val 2073825819 ecr 2863680852], length 79: HTTP: GET / HTTP/1.1
GET / HTTP/1.1
Host: 10.244.1.91:8080
User-Agent: Wget
```

The outer line is the UDP packet between the node addresses. `tcpdump` labels port 8472 as `OTV`, but the content is VXLAN. The inner line is the pod packet from `shuttle` to `probe`, and anyone on the node network can read the HTTP request.

You now know which hop Cilium encrypts, what stays outside the scope and how the two protocols differ. You have also seen the plain-text request on the wire, which is the result to compare against once encryption is on. The open question is how to turn encryption on safely.

## Common pitfalls

> [!WARNING]
> - **Assuming same-node traffic is encrypted.** Packets between two pods on one node stay inside the node, and Cilium does not encrypt them.
> - **Assuming external traffic is encrypted.** Traffic to destinations outside the cluster is not covered.
> - **Expecting workload identity.** Encryption protects the path; it does not tell the receiver which pod sent the packet.
> - **Capturing on the wrong interface.** Capture on the node interface `eth0`. Inside a pod the packets are always plain text.
