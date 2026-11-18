---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Enable WireGuard Encryption In Cilium Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Cilium transparent encryption encrypts packets between nodes in the kernel. The pods send plain TCP and do not take part. With the type `wireguard`, each Cilium agent creates the network interface `cilium_wg0` on its node, generates a WireGuard key pair, publishes its public key on the CiliumNode object of its node and adds every other node as a WireGuard peer. The agent reads these settings only when it starts.

The settings live in the Helm values. Change only the two encryption values and keep everything else with `--reuse-values`:

```sh
helm upgrade cilium cilium --repo https://helm.cilium.io --version 1.20.4 --namespace kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard
```

Helm updates the ConfigMap `cilium-config`, but the running agents keep their old settings. Restart the DaemonSet and wait until every new agent pod is ready:

```sh
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

Then check the result on each agent. List the agent pods, then run the status command in each one:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent reports `Encryption: Wireguard`, the interface `cilium_wg0`, its public key and `Number of peers: 1`. The peer is the agent on the other node. The agent container also has the `ip` tool and shares the network of its node, so you can see the interface itself:

```sh
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- ip -d link show cilium_wg0
```

The output shows a link of type `wireguard`. Its MTU (maximum transmission unit, the largest packet the interface sends) is lower than the MTU of `eth0`, because WireGuard adds its own header to each packet. Finally, send a request from `shuttle` to the `probe` Service:

```sh
kubectl -n starfleet-034-040-03-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-01.svc.cluster.local:8080/
```

The reply is `probe-reply`. The request now leaves the control-plane node through `cilium_wg0` as UDP packets on port 51871, and the kernel of the worker node decrypts them before they reach the `probe` pod. The grader checks this by reading the transmitted byte count of `cilium_wg0` before and after one request.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> Running `helm upgrade` with `--set` but without `--reuse-values` can reset the other values of the release to the chart defaults. Keep `--reuse-values` when you change only one setting.
>
> The agents read the encryption settings when they start. Until you restart the DaemonSet, `cilium-dbg encrypt status` still reports `Encryption: Disabled`.
>
> Check every agent, not only one with `ds/cilium`. One agent without a peer leaves the traffic of its node in plain text.
