---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prepare IPsec Encryption For Cilium

Create the IPsec key Secret and set the Helm values so that Cilium encrypts node-to-node traffic with IPsec.

## Starting state

The isolated environment is a `kind` cluster with one control-plane node and one worker node. It does not run Cilium. The ConfigMap `cilium-values` in `kube-system` holds the Helm values file of the cluster as the key `values.json`, and encryption is disabled in it. No Secret named `cilium-ipsec-keys` exists.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection selected for the whole task.

## Required result

The nodes of the target cluster run a kernel older than 5.6, so WireGuard is not an option and the cluster must use IPsec. Deliver two results.

1. **Key Secret.** A Secret named `cilium-ipsec-keys` in `kube-system` has the data key `keys`. Its value is one line with a SPI, the algorithm `rfc4106(gcm(aes))`, a random key of 40 hexadecimal characters and the length `128`.
2. **Helm values.** The key `values.json` in the ConfigMap `cilium-values` sets `encryption.enabled` to `true`, `encryption.type` to `ipsec` and `encryption.ipsec.secretName` to the name of the Secret.

## Verify the result

Read the Secret without printing the key, and read the values file back. The grader checks the format of the key line and the JSON in the ConfigMap.
