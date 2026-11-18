---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Cilium WireGuard And IPsec Encryption

Istio encrypts the traffic of pods that have a sidecar proxy. Pods without a sidecar, and traffic that the mesh does not cover, stay in plain text. Cilium closes that gap at the network layer: it encrypts packets between nodes in the Linux kernel, for every pod, with no change to the application and no sidecar. This module shows what that encryption protects, how to turn it on with WireGuard or IPsec, how to rotate the IPsec key and how to prove that packets are encrypted.

Cilium is a Container Network Interface (CNI) plugin. A CNI plugin gives each pod its network and moves packets between pods. Cilium does this with eBPF programs, small programs that run inside the Linux kernel, and it sets up the encryption in the same place. WireGuard and IPsec (Internet Protocol Security) are two protocols that encrypt IP packets between two hosts.

## Learning objectives

After this module you can:

- Say which traffic Cilium encryption protects and which traffic it leaves in plain text.
- Turn on WireGuard encryption with Helm and confirm the peers on every Cilium agent.
- Create the IPsec key Secret in the correct format, switch Cilium to IPsec and rotate the key to a new SPI.
- Prove encryption with `cilium-dbg`, the kernel state of each node and a packet capture, and state the limits of the result.

## Before you start

You need pods, nodes, namespaces, DaemonSets and Secrets, and the commands `kubectl get`, `kubectl exec` and `kubectl create`. You also need Helm, the package manager for Kubernetes, on your machine. The module first shows what Cilium encrypts and captures plain-text traffic. It then turns on WireGuard, switches to IPsec and rotates the key, and it ends with a full verification and the limits. A graded lab follows the WireGuard reading and another follows the IPsec reading.

Your playground is a kind cluster running Kubernetes 1.35 with one control-plane node and one worker node. Cilium 1.20.4 is its network plugin, with encryption turned off. This module needs Docker or rootful Podman, because Cilium mounts the BPF filesystem on each node; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`. Launch your playground now and keep it running while you read:

<!-- astrona:playground -->
