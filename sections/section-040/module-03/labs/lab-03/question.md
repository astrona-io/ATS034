---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Fix A Cilium Agent That Did Not Load WireGuard

Allow about 10 minutes for the tasks.

This lab needs Docker or rootful Podman, because Cilium mounts the BPF filesystem on each node; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`.

A colleague turned on WireGuard in the Cilium Helm release and checked one Cilium agent, which reported `Encryption: Wireguard`. The traffic between the nodes is still not fully encrypted. Find the node that is not protected, record it and fix the cluster so that every node encrypts its traffic.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Cilium 1.20.4 is the network plugin of the cluster. Cilium is a Container Network Interface (CNI) plugin: it gives each pod its network and moves packets between pods with eBPF programs in the Linux kernel. It runs as the Helm release `cilium` in `kube-system`, from the chart `cilium` in the repository `https://helm.cilium.io`, version `1.20.4`. The release already has the values `encryption.enabled=true` and `encryption.type=wireguard`. The Cilium agent runs as the DaemonSet `cilium` on both nodes, and its pods have the label `k8s-app=cilium`.

The namespace `starfleet-034-040-03-03` runs the pod `probe` on the worker node, with a BusyBox HTTP server on port 8080 that answers `probe-reply`, and the Service `probe` on port 8080. The pod `shuttle` runs on the control-plane node and has BusyBox `wget` in its container `client`.

## Tasks

1. Check the encryption status of every Cilium agent. In `starfleet-034-040-03-03`, create a ConfigMap named `encryption-diagnosis` with the key `node`. Its value is the name of the node whose agent did not report `Encryption: Wireguard`.
2. Fix the cause so that every Cilium agent reports `Encryption: Wireguard`. Do not change the Helm values.
3. Every agent must have one WireGuard peer for each other node, and the `shuttle` pod must still get `probe-reply` from `http://probe.starfleet-034-040-03-03.svc.cluster.local:8080/`. Do not move or change the pods.

## Check your work

Read the ConfigMap, then ask each Cilium agent for its encryption state:

```sh
kubectl -n starfleet-034-040-03-03 get configmap encryption-diagnosis -o jsonpath='{.data.node}'
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent must report `Encryption: Wireguard` and `Number of peers: 1`. Then send one request across the nodes:

```sh
kubectl -n starfleet-034-040-03-03 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-03.svc.cluster.local:8080/
```

The command must print `probe-reply`.
