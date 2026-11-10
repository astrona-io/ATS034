---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prepare IPsec Encryption For Cilium

Solve this question on: `terminal`

The nodes of the target cluster run a kernel older than 5.6, so WireGuard is not an option and the cluster must use IPsec. The environment is a `kind` cluster with one control-plane node and one worker node. It does not run Cilium. The ConfigMap `cilium-values` in `kube-system` holds the Helm values file of the cluster as the key `values.json`, and encryption is disabled in it. No Secret named `cilium-ipsec-keys` exists.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

Keep this connection selected for the whole task.

Allow about 7 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the Secret `cilium-ipsec-keys` in `kube-system` with the data key `keys`. Its value is one line with a SPI, the algorithm `rfc4106(gcm(aes))`, a random key of 40 hexadecimal characters and the length `128`.
2. Edit the key `values.json` in the ConfigMap `cilium-values` so that it sets `encryption.enabled` to `true`, `encryption.type` to `ipsec` and `encryption.ipsec.secretName` to the name of the Secret.

## Constraints

- Do not print the key. Read the Secret back without decoding the key on screen.
- Keep the rest of `values.json` as it is.

## How the answer is checked

This exercise checks the inputs to an IPsec installation. No Cilium agent consumes the stored values here, so a passing result is not evidence of encrypted traffic or successful key rotation.

The grader runs two checks: the format of the key line in `cilium-ipsec-keys`, and the encryption fields in the JSON of `cilium-values`.

Hint: `openssl rand -hex 20` prints 40 hexadecimal characters.
