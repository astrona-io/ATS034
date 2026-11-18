---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Enable WireGuard Encryption In Cilium

Allow about 10 minutes for the tasks.

This lab needs Docker or rootful Podman, because Cilium mounts the BPF filesystem on each node; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`.

The `shuttle` pod and the `probe` pod in `starfleet-034-040-03-01` run on different nodes, and their traffic crosses the node network in plain text. Encrypt all pod traffic between the nodes with WireGuard.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Cilium 1.20.4 is the network plugin of the cluster. Cilium is a Container Network Interface (CNI) plugin: it gives each pod its network and moves packets between pods with eBPF programs in the Linux kernel. It was installed with Helm as the release `cilium` in `kube-system`, from the chart `cilium` in the repository `https://helm.cilium.io`, version `1.20.4`, with `encryption.enabled=false`. The agent runs as the DaemonSet `cilium` on both nodes, and pods on different nodes reach each other through a VXLAN tunnel.

The namespace `starfleet-034-040-03-01` runs the pod `probe` on the worker node, with a BusyBox HTTP server on port 8080 that answers `probe-reply`, and the Service `probe` on port 8080. The pod `shuttle` runs on the control-plane node and has BusyBox `wget` in its container `client`.

## Tasks

1. Turn on Cilium transparent encryption with the type `wireguard`. Change the existing Helm release `cilium` and keep its other values.
2. Make sure every Cilium agent runs with the new setting and has a WireGuard peer for the other node.
3. The `shuttle` pod must still get `probe-reply` from `http://probe.starfleet-034-040-03-01.svc.cluster.local:8080/`. Do not move or change the pods.

## Check your work

Ask each Cilium agent for its encryption state. The agent pods have the label `k8s-app=cilium`:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent must report `Encryption: Wireguard` and `Number of peers: 1`. Then send one request across the nodes:

```sh
kubectl -n starfleet-034-040-03-01 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-01.svc.cluster.local:8080/
```

The command must print `probe-reply`.
