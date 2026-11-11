---
draft: true
---
# Prove Cilium Encrypts A Cross-Node Request

Cilium can encrypt traffic between its managed Pods using WireGuard. The agents exchange public keys, and each node kernel creates `cilium_wg0`. Configuration alone does not prove a packet used that tunnel. This independent Ubuntu VM runs two kind nodes so the exercise has a known Linux kernel and a real cross-node path.

<!-- astrona:playground:renew -->

Run commands inside the VM and select its private cluster:

```sh
export KUBECONFIG=/etc/training/kubeconfig
kubectl -n encryption-training get pods -o wide
kubectl -n kube-system get configmap cilium-config -o yaml
```

Enable encryption using the cached chart and preserve the installation's other settings:

```sh
export KUBECONFIG=/etc/training/kubeconfig
sudo helm --kubeconfig "$KUBECONFIG" upgrade cilium /etc/training/cilium-1.20.4.tgz --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard --wait --timeout=8m
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
sleep 10
```

Inspect each node's WireGuard peers from the VM. `nsenter` runs the host's diagnostic tool in the selected node container's network namespace:

```sh
node_pid=$(sudo docker inspect --format '{{.State.Pid}}' encryption-control-plane)
sudo nsenter -t "$node_pid" -n wg show cilium_wg0
```

Repeat for `encryption-worker`. A peer entry establishes configuration; the traffic test establishes use. In two VM terminals, capture the inner and outer interfaces:

```sh
sudo nsenter -t "$node_pid" -n tcpdump -U -s 0 -i cilium_wg0 -w /tmp/inner.pcap
sudo nsenter -t "$node_pid" -n tcpdump -U -s 0 -i eth0 -w /tmp/outer.pcap
```

In a third terminal, request the application with a unique query marker:

```sh
export KUBECONFIG=/etc/training/kubeconfig
server_ip=$(kubectl -n encryption-training get pod server -o jsonpath='{.status.podIP}')
kubectl -n encryption-training exec client -- wget -T 5 -qO- "http://$server_ip:8080/?proof=student-unique-marker"
```

Stop both captures with Ctrl-C. Read them with `sudo tcpdump -A -nr /tmp/inner.pcap` and `sudo tcpdump -A -nr /tmp/outer.pcap`. The application returns `encrypted-service`. The inner capture contains the marker; the outer capture contains UDP 51871 traffic without the marker. Capture on the physical-facing interface because plaintext is expected inside the WireGuard interface.

## Common pitfalls

> [!WARNING]
> Same-node Pod traffic does not traverse this cross-node tunnel. Verify placement before claiming encryption. These captures prove the tested path and request; they do not establish encryption for every traffic type or protect data from a compromised node.
