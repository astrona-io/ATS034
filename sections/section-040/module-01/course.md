---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Pod-To-Pod Encryption With Istio And Cilium

Inside a Kubernetes cluster, Pods talk to each other over a network that the cluster operator and the cloud provider control. By default that traffic is plain text. Anyone who can capture packets on a node, a switch or a virtual network can read requests and responses, including tokens and personal data. Pod-to-Pod encryption removes that exposure without changing the application code.

This module compares the ways to encrypt Pod traffic and then works through two of them: mutual TLS (mTLS) in the Istio service mesh, and transparent encryption in the Cilium network plugin. You apply and test the Istio configuration in the playground, and you learn the Cilium configuration and its checks as a procedure for a cluster that runs Cilium.

The module has four parts. **Pod Traffic And Encryption Options** shows the default plain-text path and compares the approaches. **Istio Mutual TLS With PeerAuthentication** turns on strict mTLS for a namespace and ends with a graded task. **Authorizing Workloads With AuthorizationPolicy** uses the identity that mTLS provides to allow only chosen callers. **Cilium Transparent Encryption** explains WireGuard and IPsec encryption between nodes and how to verify it.

## Learning objectives

After this module you can:

- Explain what traffic is exposed on a cluster network by default, and which approaches encrypt it.
- Compare the sidecar mTLS of Istio with the node-to-node encryption of Cilium: identity, scope and cost.
- Require mTLS for a namespace with a `PeerAuthentication` in `STRICT` mode, and predict which clients fail.
- Allow or deny callers by workload identity with an `AuthorizationPolicy`.
- Enable Cilium encryption with WireGuard or IPsec and verify that it is active.

## Before you start

You need Kubernetes basics: Pods, namespaces, Services, labels and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You do not need any earlier module.

Your playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Istio 1.30.5 is installed in the `istio-system` namespace. The namespace `starfleet` has the label `istio-injection=enabled`, so its Pods run an Envoy sidecar proxy next to the application container. It has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas, port 8080), the `probe` Service on port 80, and `shuttle`, a `busybox` client pod. All of them have the Istio sidecar |
| `outpost` | `drifter`, a `busybox` client pod without a sidecar |
| `istio-system` | `istiod`, the Istio control plane |

The playground does not run Cilium. The Cilium part is a reference procedure with no commands to run. `kubectl` in the playground terminal already points at this cluster. Every file you save is a file on the playground machine, in the folder you are working in.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
