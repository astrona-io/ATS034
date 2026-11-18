---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Guided Practice: Encrypt Pod Traffic With Cilium

This playground is a kind cluster with two nodes and Cilium 1.20.4 as its network plugin. Cilium is a Container Network Interface (CNI) plugin: it gives each pod its network and moves packets between pods with eBPF programs in the Linux kernel. Transparent encryption is turned off at the start. This playground needs Docker or rootful Podman, because Cilium mounts the BPF filesystem on each node; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`.

Connect a host shell to the playground first. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-040-03" || exit 1
```

## Look at the starting state

The `probe` pod in the `starfleet` namespace runs on the worker node and answers `probe-reply` on port 8080. The `shuttle` pod runs on the control-plane node, so its requests to the `probe` pod cross between the nodes. The `node-tools` pods share the network of their node and contain `tcpdump`. Check where everything runs:

```sh
kubectl get pods -n starfleet -o wide
kubectl get pods -n node-tools -o wide
```

Then ask each Cilium agent for its encryption state. The agent pods have the label `k8s-app=cilium`, and `cilium-dbg` is the command-line tool inside the `cilium-agent` container:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent reports `Encryption: Disabled`. Pods on different nodes reach each other through a VXLAN tunnel on UDP port 8472, and the HTTP request travels inside it as plain text.

## Turn on WireGuard

Change the Helm release `cilium` and keep its other values. Then restart the agents, because they read the setting only when they start:

```sh
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

Run `cilium-dbg encrypt status` in each agent again. It now reports `Encryption: Wireguard`, the interface `cilium_wg0` and `Number of peers: 1`. Send a request from `shuttle` to the `probe` pod address:

```sh
PROBE_IP=$(kubectl -n starfleet get pod probe -o jsonpath='{.status.podIP}')
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://$PROBE_IP:8080/
```

The reply is `probe-reply`. Between the nodes the request now travels as UDP packets on port 51871, the WireGuard port.

## Switch to IPsec and rotate the key

IPsec needs a key that you create. Store it in the Secret `cilium-ipsec-keys` in `kube-system`, switch the encryption type and restart the agents:

```sh
kubectl -n kube-system create secret generic cilium-ipsec-keys --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system --reuse-values --set encryption.type=ipsec
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

Each agent now reports `Encryption: IPsec` and `Errors: 0`. To rotate, write a new key with a higher SPI (security parameter index, the number that names the key). The agents load it without a restart, about one minute later:

```sh
kubectl -n kube-system patch secret cilium-ipsec-keys -p "{\"stringData\":{\"keys\":\"4+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128\"}}"
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- ip xfrm state | grep -o 'spi 0x[0-9a-f]*' | sort | uniq -c
```

When the rotation is done, the second command lists `spi 0x00000004` next to `spi 0x00000003`. The `grep` keeps the keys out of your terminal, because `ip xfrm state` prints them.

## Common pitfalls

> [!WARNING]
> - **Forgetting the restart after `helm upgrade`.** The agents keep the old setting and still report the old encryption state.
> - **Using `--set` without `--reuse-values`.** Helm can reset the other values of the release to the chart defaults.
> - **Printing the IPsec key.** Show the key line with `cut -d' ' -f1,2,4` and filter `ip xfrm state`.
