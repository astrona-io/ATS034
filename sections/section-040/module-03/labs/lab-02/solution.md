---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Rotate The Cilium IPsec Key Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Cilium does not create IPsec keys and does not replace them. You write the key into the Secret, and the agents load it into the kernel of each node. The kernel stores each key in a security association (SA): a record with the source and destination address, the SPI, the algorithm and the key. The SPI is written into every encrypted packet, so the receiving kernel knows which SA, and so which key, to use. A rotation therefore needs a new SPI: with the same SPI the kernels cannot tell the old and the new key apart.

First read the current SPI. The command prints fields 1, 2 and 4 and leaves out field 3, the key:

```sh
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
```

The output is `3+ rfc4106(gcm(aes)) 128`. The plus sign tells Cilium to derive a separate key for each pair of nodes from this one key. Write the new line with SPI `4` and a new random key of 20 bytes, which `openssl` prints as 40 hexadecimal characters:

```sh
kubectl -n kube-system patch secret cilium-ipsec-keys -p "{\"stringData\":{\"keys\":\"4+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
```

The shell fills in the key, so it never appears on your screen. You do not restart the agents for a rotation. The kubelet updates the mounted Secret file in each agent pod, and the agent watches the file. After a random delay of up to 30 seconds it installs the new SAs next to the old ones and starts to send with the new key. The old SAs stay for a while, so packets that are still on the way with the old SPI are decrypted. In a test run the new key appeared about one minute after the patch.

Then check the result on each agent:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

During the change `Keys in use` grows, for example from 4 to 8, because the old and the new SAs exist together. `Errors` must stay at `0`. The SAs themselves are in the kernel. The output of `ip xfrm state` also contains the keys, so print only the SPI numbers:

```sh
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- ip xfrm state | grep -o 'spi 0x[0-9a-f]*' | sort | uniq -c
```

The new SPI appears as `spi 0x00000004`. Finally, send a request across the nodes:

```sh
kubectl -n starfleet-034-040-03-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-02.svc.cluster.local:8080/
```

The reply is `probe-reply`, so the traffic kept flowing through the rotation.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-03-02`.

## Common pitfalls

> [!WARNING]
> A new key with the same SPI is not a rotation. The kernels identify keys by SPI, so the change has no clear effect or breaks traffic between nodes that loaded different keys.
>
> `ip xfrm state` prints the keys. Filter its output, as shown, before it reaches your screen or a log.
>
> Do not judge the rotation in the first seconds. Each agent waits a random time of up to 30 seconds before it loads the new key; check again after about one minute.
