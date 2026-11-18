---
exam_objectives:
- Manage Kubernetes secrets
---
# Guided Practice: Rotate A Secret And Refresh Its Consumer

This playground is a VM (virtual machine) that runs a one-node Kubernetes 1.35 cluster built with kubeadm. The node is the control plane and also runs the pods, so you can change the kube-apiserver and read the `etcd` data on it. The namespace `starfleet` holds the `shuttle` pod and the Secret `practice-token` with the disposable value `disposable-v1`. The namespace `outpost` holds the `drifter` pod.

<!-- astrona:playground:renew -->

Open a shell on the VM. You are logged in as the `student` user, and `kubectl` already points at the cluster. Node files and processes belong to root, so run node commands with `sudo`.

```sh
astrona ssh astro-ats-034-playground-020-01
```

## Inspect the starting state

Look at the pods and the Secret before you change anything. The second command compares the stored value inside the shell and prints only `match` or `different`, so the credential never appears on the screen:

```sh
kubectl -n starfleet get pods,secrets
test "$(kubectl -n starfleet get secret practice-token -o jsonpath='{.data.token}' | base64 -d)" = disposable-v1 && echo match || echo different
```

## Rotate the value

A pod that reads a Secret through an environment variable keeps the old value until the pod is created again. A pod that mounts the Secret as a volume receives the new value from the kubelet, the agent on the node, after a short delay. Start a pod that uses both paths, then change the value.

Save this as `pod-rotated-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rotated-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    env:
    - name: PRACTICE_TOKEN
      valueFrom:
        secretKeyRef:
          name: practice-token
          key: token
    volumeMounts:
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: practice-token
```

Apply it:

```sh
kubectl apply -f pod-rotated-reader.yaml
kubectl -n starfleet wait --for=condition=Ready pod/rotated-reader --timeout=180s
```

Save this as `secret-practice-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-token
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v2
```

Apply it:

```sh
kubectl apply -f secret-practice-token.yaml
```

## Check both delivery paths

Then check the result. Run the commands a few times over the next two minutes:

```sh
kubectl -n starfleet exec rotated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v2 && echo file-new || echo file-old'
kubectl -n starfleet exec rotated-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v2 && echo env-new || echo env-old'
```

The file changes to `file-new` once the kubelet syncs the volume, which can take one to two minutes. The environment variable stays `env-old`. To load the new value into the environment, delete the pod and apply `pod-rotated-reader.yaml` again.

## Common pitfalls

> [!WARNING]
> A Secret volume mounted with `subPath` never receives an update. Mount the whole volume, as above, when the value can change.
>
> The playground is yours alone, but its kube-apiserver is real. Keep a backup outside `/etc/kubernetes/manifests` before you edit a static pod manifest.
