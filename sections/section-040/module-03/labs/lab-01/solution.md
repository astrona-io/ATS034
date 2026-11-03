---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Prepare IPsec Encryption For Cilium Solution

The task has two objects that must agree: the Secret that holds the key and the values file that names it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-01" || exit 1
```

## Inspect the starting state

Read the values file and confirm that the Secret does not exist:

```sh
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
kubectl -n kube-system get secret cilium-ipsec-keys
```

The values show `enabled` as `false`, and the second command reports that the Secret is not found.

## Create the key Secret

Create the Secret with a random key. The key has 40 hexadecimal characters, which `openssl rand -hex 20` produces:

```sh
kubectl -n kube-system create secret generic cilium-ipsec-keys --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
```

## Set the Helm values

Save this as `configmap-cilium-values-ipsec.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-values
  namespace: kube-system
data:
  values.json: |
    {
      "encryption": {
        "enabled": true,
        "type": "ipsec",
        "ipsec": {
          "secretName": "cilium-ipsec-keys",
          "keyFile": "keys",
          "mountPath": "/etc/ipsec"
        }
      }
    }
```

Apply it:

```sh
kubectl apply -f configmap-cilium-values-ipsec.yaml
```

## Verify the result

Print every field of the key line except the key, and read the values file back:

```sh
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

The first command shows the SPI, the algorithm and the length. The second shows `enabled` as `true`, the type `ipsec` and the Secret name.

After recording your result, remove the independent lab with `astrona destroy ats-034-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> - **Creating the Secret in the wrong namespace.** The agents read `kube-system` only.
> - **A key of the wrong length.** Use `openssl rand -hex 20`, which gives 40 hexadecimal characters.
> - **Values and Secret that disagree.** The `secretName` in the values must be the name of the Secret.
> - **Printing the key.** Use `cut` to hide it.
