---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Cilium 1.20.4 is the network plugin of the cluster. Cilium is a Container Network Interface (CNI) plugin: it gives each pod its network and moves packets between pods with eBPF programs in the Linux kernel. It runs as the Helm release `cilium` in `kube-system`, from the chart `cilium` in the repository `https://helm.cilium.io`, version `1.20.4`. The release already has the values `encryption.enabled=true` and `encryption.type=wireguard`. The Cilium agent runs as the DaemonSet `cilium` on both nodes, and its pods have the label `k8s-app=cilium`.

The namespace `starfleet-034-040-03-03` runs the pod `probe` on the worker node, with a BusyBox HTTP server on port 8080 that answers `probe-reply`, and the Service `probe` on port 8080. The pod `shuttle` runs on the control-plane node and has BusyBox `wget` in its container `client`.
