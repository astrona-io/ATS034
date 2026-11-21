---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# IPsec Keys And Rotation

IPsec works on kernels that do not have WireGuard, but Cilium does not create its keys. You create a key, store it in a Kubernetes Secret and replace it before it gets old. Mistakes here are quiet: a key in the wrong format or the wrong namespace leaves the agents without working encryption. This reading creates the key, switches the playground from WireGuard to IPsec and rotates the key while traffic keeps flowing.

## The key Secret

IPsec (Internet Protocol Security) encrypts IP packets in the kernel and sends them as ESP packets (Encapsulating Security Payload, IP protocol 50). The kernel keeps one security association for each direction between two hosts. A security association is a kernel entry that holds the addresses, the algorithm, the key and the SPI. The SPI (security parameter index) is the number that names the key; every ESP packet carries it, so the receiver knows which key to use.

The Cilium agents read the IPsec key from the Secret `cilium-ipsec-keys` in `kube-system`. The data key inside the Secret is `keys`, and its value is one line with four fields separated by spaces:

```text
<spi> <algorithm> <key in hexadecimal> <integrity check length>
```

- The **SPI** is a number from 1 to 15. A plus sign after it, for example `3+`, tells Cilium to derive a separate key for each pair of nodes from the one key in the Secret.
- The **algorithm** is `rfc4106(gcm(aes))`, AES (Advanced Encryption Standard) in GCM (Galois/Counter Mode).
- The **key** is 40 hexadecimal characters: a 128-bit key and a 32-bit salt.
- The **integrity check length** is `128`, the size in bits of the check value that detects changed packets.

Create the Secret with a random key from `openssl`:

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system create secret generic cilium-ipsec-keys --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
```

The second command prints every field except the key: `3+ rfc4106(gcm(aes)) 128`. Anyone who has the key can decrypt the captured traffic, so never print it in a shared terminal or a log.

## Switch the agents to IPsec

The Helm value `encryption.type` selects the protocol, and the chart mounts the Secret into every agent pod at `/etc/ipsec`. The default Secret name in the chart is `cilium-ipsec-keys`, so no other value is needed. Change the type and restart the agents:

```sh
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system --reuse-values --set encryption.type=ipsec
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

A cluster uses one protocol at a time. While the agents restart, one node can already use IPsec and the other still WireGuard, so traffic between them can fail for a short time. Now ask each agent for its state:

```sh
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

In a test run each agent printed this:

```text
Encryption: IPsec
Decryption interface(s): eth0
Keys in use: 4
Max Seq. Number: N/A
Errors: 0
```

`Keys in use` counts the security associations that the agent installed in the kernel. `Errors` counts packets that the kernel could not encrypt or decrypt, for example because the two nodes hold different keys. It must stay at 0.

The security associations themselves are in the kernel of each node. `ip xfrm state` lists them, and it also prints the keys, so always filter its output:

```sh
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- ip xfrm state | grep -o 'spi 0x[0-9a-f]*' | sort | uniq -c
```

In a test run this printed `4 spi 0x00000003`: four security associations, all with SPI 3, the number from the Secret. The `cilium_wg0` interface no longer exists on the nodes.

## Rotate the key

Cilium does not rotate IPsec keys by itself, so plan rotations, for example every few months. To rotate, write a new key with a higher SPI into the same Secret. The agents name keys by their SPI, so a new key with the same SPI is not a rotation:

```sh
kubectl -n kube-system patch secret cilium-ipsec-keys -p "{\"stringData\":{\"keys\":\"4+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
```

The kubelet, the node agent of Kubernetes, updates the mounted file in each agent pod, and the agent sees the change. No restart is needed. Run the filtered `ip xfrm state` command again about every 15 seconds. In a test run it showed only SPI 3 for more than a minute, then this:

```text
      4 spi 0x00000003
      4 spi 0x00000004
```

At the same moment `cilium-dbg encrypt status` showed `Keys in use: 8` and `Errors: 0`. The agent installs the new key next to the old one, so packets that are still in flight with SPI 3 can be decrypted. New packets leave with the new SPI: in a test run, a packet capture on `eth0` of a node showed `ESP(spi=0x00000004,...)` in both directions at about the time both nodes listed SPI 4, and no packet with SPI 3 after that. On a node without `tcpdump`, `kubectl debug node/<node> --profile=sysadmin --image=<image with tcpdump> -- tcpdump -ni eth0 esp` runs the capture in a privileged pod in the network namespace of the node, and `kubectl logs` on that pod shows the result. The agent log shows why the change took a while:

```sh
kubectl -n kube-system logs <cilium-pod> -c cilium-agent | grep -i ipsec
```

Two lines of a test run, shortened, were `Applying jitter before loading IPsec keys ... maxJitter=30s` and `Loaded IPsec keyfile ... spi=4 file-path=/etc/ipsec/keys`. Each agent waits a random time of up to 30 seconds before it loads the key, so the nodes do not all change at once. The agent then keeps the old key for the time set by its flag `--ipsec-key-rotation-duration`, which was `5m` in the playground, and removes it after that.

You now know the whole life of an IPsec key: create it in the right format, switch the agents to IPsec and replace the key with a higher SPI while traffic keeps flowing. What is still open is how to prove, on every node and on the wire, that the encryption works, and what that proof does not cover.

## Common pitfalls

> [!WARNING]
> - **Creating the Secret in another namespace.** The agents read `kube-system` only, so they start without a key.
> - **Using a wrong key length.** The key must have 40 hexadecimal characters for `rfc4106(gcm(aes))`.
> - **Rotating with the same SPI.** The agents cannot tell the keys apart, and the change has no effect.
> - **Judging the rotation too early.** Each agent waits up to 30 seconds, and the kubelet can take a minute to update the file. Check `ip xfrm state` on every node.
> - **Printing the key.** `ip xfrm state` and the Secret both contain it. Filter with `grep -o 'spi 0x[0-9a-f]*'` and `cut -d' ' -f1,2,4`.
