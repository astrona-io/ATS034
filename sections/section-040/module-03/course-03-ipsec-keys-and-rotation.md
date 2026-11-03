---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# IPsec Keys And Rotation

IPsec works on kernels that do not have WireGuard, but Cilium does not generate its keys. You create a key, store it in a Kubernetes Secret, and replace it before it ages. Mistakes here are quiet: a key in the wrong format or the wrong namespace leaves the agents without encryption. This part shows the key format, the Secret, the Helm values and the rotation procedure.

## The key Secret

Cilium agents read the IPsec key from a Secret in the `kube-system` namespace. The default Secret name is `cilium-ipsec-keys`, and the data key inside it is `keys`. The value is one line with four fields separated by spaces:

```text
<spi> <algorithm> <key in hexadecimal> <integrity check length>
```

- The **SPI** (security parameter index) is a small integer that identifies the key. A plus sign after it, for example `3+`, tells Cilium to derive a separate key for each tunnel.
- The **algorithm** is `rfc4106(gcm(aes))`, which is AES in GCM mode.
- The **key** is 40 hexadecimal characters: a 128-bit key and a 32-bit salt.
- The **integrity check length** is `128`.

Create the Secret with a random key. The command below needs the `openssl` tool and a cluster, and it works in the playground:

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system create secret generic cilium-ipsec-keys --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
```

Print every field except the key, so that the key does not appear on your screen:

```sh
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
```

The output shows the SPI, the algorithm and the length. Never print the key itself in a shared terminal or a log.

## Tell Helm to use the Secret

The Helm values for IPsec name the Secret. Save this as `configmap-cilium-values-ipsec.yaml`:

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
        "type": "ipsec",
        "ipsec": {
          "secretName": "cilium-ipsec-keys",
          "keyFile": "keys",
          "mountPath": "/etc/ipsec"
        }
      }
    }
```

Apply it and read the values back:

```sh
kubectl apply -f configmap-cilium-values-ipsec.yaml
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

The setting `secretName` names the Secret, `keyFile` names the data key inside it and `mountPath` is the directory where the agent finds the file. The values shown are the chart defaults, and writing them out makes the file easy to review. On a real cluster the file goes to `helm upgrade`, and the agents restart to load it.

## Rotate the key

A key should not live for ever. To rotate, replace the value in the Secret with a new key and a higher SPI. The agents watch the Secret, install the new key next to the old one and switch to it, so the traffic keeps flowing. Do the rotation like this:

```sh
kubectl -n kube-system patch secret cilium-ipsec-keys -p "{\"stringData\":{\"keys\":\"4+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
```

The second command shows that the SPI is now `4`. A key with the same SPI as the old one is not a rotation, because the agents identify keys by the SPI. Keep the old value until all nodes use the new one, and schedule rotations, for example every few months, because Cilium does not rotate IPsec keys on its own.

You now know the full life of an IPsec key: create it in the right format, name it in the values and replace it with a higher SPI. The last part of the module checks that a configuration works on the wire.

## Common pitfalls

> [!WARNING]
> - **Creating the Secret in another namespace.** The agents read `kube-system` only, so they start without a key.
> - **Using a wrong key length.** The key must have 40 hexadecimal characters for this algorithm.
> - **Rotating with the same SPI.** The agents cannot tell the keys apart and the change has no effect.
> - **Printing the key.** Anyone who sees it can decrypt the traffic. Use `cut` as shown.
> - **Forgetting that rotation is manual.** Without a schedule, the key stays for the life of the cluster.
