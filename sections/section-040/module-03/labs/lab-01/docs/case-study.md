---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Starting Environment

The isolated environment is a `kind` cluster with one control-plane node and one worker node. It does not run Cilium. The ConfigMap `cilium-values` in `kube-system` holds the Helm values file of the cluster as the key `values.json`, and encryption is disabled in it. No Secret named `cilium-ipsec-keys` exists.
