---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Guided Practice: Prepare IPsec Encryption For Cilium

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-playground-040-03" || exit 1
```

Keep this connection selected. The cluster does not run Cilium. You prepare the two objects that a Cilium installation reads.

## Inspect the starting state

```sh
kubectl get nodes -o wide
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

The values show that encryption is disabled.

## Create the key and set the values

```sh
kubectl -n kube-system create secret generic cilium-ipsec-keys --from-literal=keys="3+ rfc4106(gcm(aes)) $(openssl rand -hex 20) 128"
```

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

Print the key line without the key, and read the values file back:

```sh
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
kubectl -n kube-system get configmap cilium-values -o jsonpath='{.data.values\.json}'
```

## Common pitfalls

> [!WARNING]
> A Secret in a namespace other than `kube-system` is not read by the agents. The `secretName` in the values must match the Secret.
