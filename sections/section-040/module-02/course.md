---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Operate Istio Mutual TLS

Turning on mutual TLS (mTLS) in Istio is one object, but running it in a real cluster is a set of decisions. You must know which policy wins when several overlap, how to move a namespace from plain text to encrypted traffic without an outage, where the certificates come from and how to prove that a connection is encrypted. This module covers those operating tasks for the Istio service mesh.

A service mesh is a layer of sidecar proxies (Envoy) that handle the network traffic of the application Pods. Istio adds a control plane, `istiod`, that gives each proxy a certificate and its configuration. mTLS means that both sides of a connection present a certificate, so each side knows who the other is, and the traffic is encrypted.

## Learning objectives

After this module you can:

- Choose the correct scope for a `PeerAuthentication` (mesh, namespace, workload or port) and predict which policy wins.
- Migrate a namespace from `PERMISSIVE` to `STRICT` and keep one legacy workload reachable with a narrow exception.
- Explain how `istiod` issues and rotates workload certificates and what a SPIFFE identity contains.
- Verify that a connection uses mTLS and diagnose the common reasons it fails.

## Before you start

You need Pods, namespaces, Services and the commands `kubectl apply`, `kubectl get` and `kubectl exec`. You should know what a sidecar proxy is and that a `PeerAuthentication` with `mtls.mode: STRICT` makes the receiving sidecar reject plain text. The module has four parts. The first covers modes, scopes and precedence. The second migrates a namespace to `STRICT`. The third explains certificates and identity. The fourth verifies and troubleshoots mTLS.

Your playground is a `kind` cluster running Kubernetes 1.35 with Istio 1.30.5 in the `istio-system` namespace. The namespace `starfleet` has the label `istio-injection=enabled`, so its Pods run an Envoy sidecar next to the application container.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment (two replicas, port 8080) with a Service on port 80, the `legacy` Deployment (one replica, port 8080) with a Service on port 80, and `shuttle`, a `busybox` client Pod. All of them have the sidecar |
| `outpost` | `drifter`, a `busybox` client Pod without a sidecar |
| `istio-system` | `istiod`, the Istio control plane |

`kubectl` in the playground terminal already points at this cluster. Launch your playground now and keep it running while you read:

<!-- astrona:playground -->
