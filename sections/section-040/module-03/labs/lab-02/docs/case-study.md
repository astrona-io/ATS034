---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

Cilium 1.20.4 is the network plugin of the cluster, installed with Helm as the release `cilium` in `kube-system` with `encryption.enabled=true` and `encryption.type=ipsec`. IPsec (Internet Protocol Security) encrypts each IP packet between the nodes with a shared key. The agents read the key from the Secret `cilium-ipsec-keys` in `kube-system`, data key `keys`. It holds one line with four fields: the SPI (security parameter index, the number that names the key) `3+`, the algorithm `rfc4106(gcm(aes))`, a key of 40 hexadecimal characters and the length `128`.

The namespace `starfleet-034-040-03-02` runs the pod `probe` on the worker node, with a BusyBox HTTP server on port 8080 that answers `probe-reply`, and the Service `probe` on port 8080. The pod `shuttle` runs on the control-plane node and has BusyBox `wget` in its container `client`.
