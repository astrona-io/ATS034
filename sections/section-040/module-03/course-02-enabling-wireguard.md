---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Enabling WireGuard

WireGuard is the shorter path to node-to-node encryption in Cilium, because the agents create and exchange the keys by themselves. What remains for you is the Helm configuration, the network ports and a safe rollout. This part writes the values, explains each setting and lists what to check before you restart the agents.

## How Cilium sets up WireGuard

When WireGuard is enabled, each Cilium agent creates a WireGuard interface called `cilium_wg0` on its node and generates a key pair. The private key stays on the node. The agent publishes the public key as an annotation on the node object, and every other agent reads the annotations and adds each remote node as a peer. The agent then routes packets for remote Pods through the interface. When a node joins or leaves, the agents add or remove the peer without your help.

Because the kernel needs a route to every peer, the nodes must reach each other on UDP port 51871. A firewall or a cloud security group that drops this port breaks the tunnel.

## The Helm values

These settings control WireGuard in the Cilium chart:

- `encryption.enabled`: set to `true` to turn encryption on.
- `encryption.type`: set to `wireguard`. The other value is `ipsec`.
- `encryption.nodeEncryption`: when `true`, Cilium also encrypts traffic between the nodes themselves and traffic of Pods that use host networking. The default is `false`, which covers Pod traffic only.
- `encryption.strictMode.enabled`: in recent versions, when `true`, Cilium drops Pod traffic between nodes that it cannot send encrypted, instead of sending it in plain text. Set `encryption.strictMode.cidr` to the Pod network range.

Helm accepts a values file in YAML or JSON. In the playground the file is stored as a ConfigMap. Save this as `configmap-cilium-values-wireguard.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-values
  namespace: kube-system
data:
  values.json: |
    {
      "encryption": {
        "enabled": true,
        "type": "wireguard",
        "nodeEncryption": true
      }
    }
```

Apply it and read the value back:

<!-- astrona:playground:renew -->

```sh
kubectl apply -f configmap-cilium-values-wireguard.yaml
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

The second command shows the three settings. This ConfigMap does not change any network, because the playground does not run Cilium. It is the file you would pass to Helm.

## Roll it out on a cluster with Cilium

On a cluster that runs Cilium, apply the same settings with Helm and restart the agents. Do not run these two commands in the playground:

```sh
helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard --set encryption.nodeEncryption=true
kubectl -n kube-system rollout restart daemonset/cilium
```

The restart makes each agent start with encryption, and it restarts them one node at a time. During the change a connection that was open before may keep its old path, so plan a short window and do not judge success from an old connection. WireGuard also adds a header to each packet, so the usable packet size shrinks. Cilium lowers the MTU of the Pod interfaces itself, but a network that already uses a small MTU can still show fragmentation.

You now have the values and the rollout steps. A rollout is only finished when you have proof that packets are encrypted. First, the other protocol, IPsec, needs keys that you create and rotate yourself.

## Common pitfalls

> [!WARNING]
> - **Blocking UDP 51871 between nodes.** The tunnel cannot form, and traffic breaks or stays unprotected.
> - **Using `--set` without `--reuse-values`.** Helm can reset other values to their defaults.
> - **Forgetting the restart.** The agents read the settings only when they start.
> - **Leaving `nodeEncryption` off when host-network traffic matters.** Pods that use host networking stay in plain text.
> - **Treating the Helm value as proof.** A value in a file does not prove that the traffic is encrypted.
