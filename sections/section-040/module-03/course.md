---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Cilium WireGuard And IPsec Encryption

Istio encrypts the traffic of Pods that have a sidecar. Pods without a sidecar, and traffic that the mesh does not cover, stay in plain text. Cilium closes that gap from below: it encrypts packets between nodes in the kernel, for every Pod, with no change to the application and no sidecar. This module covers what that encryption protects, how to enable it with WireGuard or IPsec, how to manage the IPsec keys and how to verify it.

Cilium is a Container Network Interface (CNI) plugin. A CNI plugin sets up the network of each Pod and moves packets between Pods. Cilium does this with eBPF programs in the Linux kernel, and it configures encryption in the same place. WireGuard and IPsec are two protocols that encrypt IP packets between two hosts.

## Learning objectives

After this module you can:

- Say which traffic Cilium encryption protects and which traffic it leaves in plain text.
- Choose between WireGuard and IPsec for a cluster and check the requirements of each.
- Write the Helm values that enable each protocol, and create the IPsec key Secret in the correct format.
- Rotate IPsec keys and verify with the Cilium agent and a packet capture that encryption is active.

## Before you start

You need Pods, nodes, namespaces, Secrets, ConfigMaps and the commands `kubectl apply`, `kubectl get` and `kubectl create`. You should know what a CNI plugin does. The module has four parts. The first explains what Cilium encrypts. The second enables WireGuard. The third sets up IPsec keys and rotation. The fourth verifies encryption and lists its limits.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. It does not run Cilium, because `kind` uses its own CNI plugin and the encryption needs a kernel and a network that the playground does not control. You do the work that you can do without it: you write the Helm values, you create the key Secret and you check the files that a Cilium installation reads. The commands that talk to Cilium agents are shown as a procedure for a real cluster, and the text says when a command does not run in the playground.

The playground has one ConfigMap, `cilium-values` in `kube-system`. It stands for the Helm values file of a cluster and holds the starting values, with encryption turned off. Launch your playground now and keep it running while you read:

<!-- astrona:playground -->
