---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Cilium Agent That Did Not Load WireGuard Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The Cilium agent is the pod of the DaemonSet `cilium` on each node. It reads its settings from the ConfigMap `cilium-config` only when it starts. So a correct Helm value does not prove that every agent uses it, and a check of one agent says nothing about the others. Start with a loop that asks every agent pod for its encryption status:

```sh
for agent_pod in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
  echo "== $agent_pod on $(kubectl -n kube-system get $agent_pod -o jsonpath='{.spec.nodeName}')"
  kubectl -n kube-system exec $agent_pod -c cilium-agent -- cilium-dbg encrypt status
done
```

In a test run, the loop printed this (the pod names and the key differ in your cluster):

```text
== pod/cilium-2zmsp on astro-ats-034-lab-040-03-03-worker
Encryption: Disabled
== pod/cilium-jv4xr on astro-ats-034-lab-040-03-03-control-plane
Encryption: Wireguard
Interface: cilium_wg0
	Public key: GRyDx8y4WIjk6uTqCDTJdmjLqb9eD0l7kRSEdmUAAns=
	Number of peers: 0
```

The agent on the worker node reports `Encryption: Disabled`. The agent on the control-plane node runs WireGuard, but it has no peer. A WireGuard peer is another node whose public key the agent knows. Each agent publishes its public key on the CiliumNode object of its node, and the agent on the worker node never created a key, so the other agent has nobody to send encrypted packets to. One stale agent breaks encryption on both nodes.

Next, confirm that the configuration itself is right. The Helm release and the ConfigMap both have WireGuard turned on:

```sh
helm -n kube-system get values cilium
kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}'
```

The values show `encryption.enabled: true` and `type: wireguard`, and the ConfigMap prints `true`. So the settings are correct, and the cause is the agent on the worker node: it did not restart after `helm upgrade`. Record that node in the ConfigMap the task asks for. Use the node name from the loop:

```sh
kubectl -n starfleet-034-040-03-03 create configmap encryption-diagnosis --from-literal=node=astro-ats-034-lab-040-03-03-worker
```

Then check the result:

```sh
kubectl -n starfleet-034-040-03-03 get configmap encryption-diagnosis -o jsonpath='{.data.node}'
```

It prints `astro-ats-034-lab-040-03-03-worker`. Now fix the cause. Restart the DaemonSet, so that the kubelet starts a new agent pod on every node, and wait until all of them are ready:

```sh
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
```

The last line is `daemon set "cilium" successfully rolled out`. Run the same loop again. In the test run, it printed this:

```text
== pod/cilium-tc2pf on astro-ats-034-lab-040-03-03-worker
Encryption: Wireguard
Interface: cilium_wg0
	Public key: DSKBxgy7rZDOyCDrCtRCmT9obrPXX5sosdY14G+KQSo=
	Number of peers: 1
== pod/cilium-z4gcd on astro-ats-034-lab-040-03-03-control-plane
Encryption: Wireguard
Interface: cilium_wg0
	Public key: GRyDx8y4WIjk6uTqCDTJdmjLqb9eD0l7kRSEdmUAAns=
	Number of peers: 1
```

Both agents now report `Encryption: Wireguard` and one peer, which is the number of other nodes. The agent on the control-plane node kept its public key after the restart, because the agent keeps its private key in the file `/var/run/cilium/state/cilium_wg0.key`, a host directory of the node. Finally, send a request from `shuttle` to the `probe` Service across the nodes:

```sh
kubectl -n starfleet-034-040-03-03 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-03.svc.cluster.local:8080/
```

The reply is `probe-reply`. Before the fix, the same command failed in the test run with `wget: bad address 'probe.starfleet-034-040-03-03.svc.cluster.local:8080'`. Both CoreDNS pods ran on the worker node, so even the DNS lookup of `shuttle` had to cross the nodes from the agent that had no peer.

When you are done, remove the lab with `astrona destroy ats-034-lab-040-03-03`.

## Common pitfalls

> [!WARNING]
> Checking one agent only. The agent on the control-plane node reported `Encryption: Wireguard`, and the problem was on the other node. Run the status command in every agent pod.
>
> Running `helm upgrade` again. The values are already correct, and Helm changes only the ConfigMap `cilium-config`, so the running agents keep their old settings. Restart the DaemonSet instead.
>
> Recording the pod name instead of the node name. The pod name changes with every restart; the ConfigMap must hold the name of the node.
