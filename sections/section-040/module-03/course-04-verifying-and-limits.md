---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Verifying Cilium Encryption And Its Limits

A Helm value and a running agent are not proof that packets are encrypted. One agent can miss a peer or hold an old key, and only its node is then unprotected. This reading builds a check that runs on every agent, proves the result on the wire with a packet capture and lists the limits you must state when you report the result. The commands below assume the playground runs IPsec with a rotated key.

## Check every agent

A check of one agent says nothing about the others. A short loop runs the same command in every agent pod. The pods have the label `k8s-app=cilium`, and the name of the node is in the pod spec:

<!-- astrona:playground:renew -->

```sh
for agent_pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
  echo "== $agent_pod on $(kubectl -n kube-system get $agent_pod -o jsonpath='{.spec.nodeName}')"
  kubectl -n kube-system exec $agent_pod -c cilium-agent -- cilium-dbg encrypt status
done
```

Every agent must name the same protocol. For IPsec, `Errors` must be 0 on every node. For WireGuard, `Number of peers` must equal the number of other nodes. An agent that reports `Encryption: Disabled` did not load the setting, usually because it was not restarted.

The second layer is the kernel of each node. The same loop with the filtered `ip xfrm state` command shows which SPI each node uses:

```sh
for agent_pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
  echo "== $agent_pod"
  kubectl -n kube-system exec $agent_pod -c cilium-agent -- ip xfrm state | grep -o 'spi 0x[0-9a-f]*' | sort | uniq -c
done
```

All nodes must list the SPI of the Secret. A node that lists only an older SPI did not load the new key, and its traffic to the other nodes fails or uses the old key. For WireGuard, the same loop with `ip -d link show cilium_wg0` shows the interface on each node, and the command fails on a node without it.

## Check the wire

The strongest proof is a packet capture on the node interface while two pods on different nodes talk. ESP is its own IP protocol, so the `tcpdump` filter is `esp`, not a port. Start the capture on the worker node in a second terminal:

```sh
WORKER_TOOLS=$(kubectl -n node-tools get pod -o name --field-selector spec.nodeName=astro-ats-034-playground-040-03-worker)
kubectl -n node-tools exec $WORKER_TOOLS -- timeout 10 tcpdump -ni eth0 -c 4 esp
```

In the first terminal, send a request from `shuttle` to the `probe` pod:

```sh
PROBE_IP=$(kubectl -n starfleet get pod probe -o jsonpath='{.status.podIP}')
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://$PROBE_IP:8080/
```

The reply is `probe-reply`. In a test run, before the key rotation, the capture showed lines like `IP 10.89.0.2 > 10.89.0.3: ESP(spi=0x00000003,seq=0x8), length 144` (timestamp removed). The packet goes between the node addresses, its SPI names the key that encrypted it and the request text is not visible. If a capture on `eth0` shows the readable HTTP request between the nodes, as the VXLAN capture did before encryption was on, the traffic is not encrypted.

## Diagnose a problem

Most failures show up in one of the checks above. This table links each symptom to the component that causes it:

| Symptom | Likely cause | Check |
| --- | --- | --- |
| `Encryption: Disabled` on an agent | The agent did not restart after `helm upgrade` | Restart the DaemonSet and read the status again |
| WireGuard `Number of peers` is too low | UDP 51871 is blocked between the nodes | Capture `udp port 51871` on both nodes |
| The agent does not start with IPsec | The Secret is missing or in another namespace | `kubectl -n kube-system get secret cilium-ipsec-keys` and the agent log |
| IPsec `Errors` rises, cross-node requests fail | The nodes hold different keys | Compare the SPI list on every node |
| The new SPI is missing after a rotation | The agent has not loaded the file yet | Wait up to two minutes and read the agent log |
| Throughput is lower | Encryption uses CPU and adds a header to each packet | Measure before and after |

## State the limits

When you report that pod traffic is encrypted, also say what the result does not cover. Cilium encryption protects traffic between nodes. It does not protect traffic between two pods on one node, and it does not protect traffic that leaves the cluster. With `nodeEncryption` off, traffic of pods that use host networking also stays in plain text. Cilium encryption does not identify the sending pod, so it does not replace a NetworkPolicy or an Istio `AuthorizationPolicy`. It also does not protect against an attacker who controls a node, because the node holds the keys.

Cilium and Istio work well together. Cilium encrypts every packet between nodes, including pods without a sidecar. Istio mTLS (mutual Transport Layer Security) adds the workload identity, and its policies can allow or deny requests by that identity. Traffic of pods in the mesh is then encrypted twice, which costs extra CPU, and many clusters accept that cost for the layered result.

You can now prove Cilium encryption on every node and on the wire, link a failed check to its cause and write an honest report of what is covered. That completes the work on Cilium transparent encryption.

## Common pitfalls

> [!WARNING]
> - **Checking one agent only.** One node with a missing peer or an old key leaves its own traffic unprotected.
> - **Capturing inside a pod.** The pod sees plain text in every case. Capture on the node interface `eth0`.
> - **Filtering ESP by port.** ESP has no ports. Use the filter `esp`.
> - **Reporting full coverage.** Same-node traffic, external traffic and, without `nodeEncryption`, host-network traffic are outside the scope.
> - **Mixing up encryption and authorization.** Encryption does not say which pod sent the packet.
