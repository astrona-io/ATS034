---
exam_objectives:
- Manage Kubernetes secrets
---
# Guided Practice: Move A Credential From A ConfigMap Into A Secret

This playground is a VM (virtual machine) that runs a one-node Kubernetes 1.35 cluster built with kubeadm. The node is the control plane and also runs the pods, so you can change the kube-apiserver and read its audit log on the node. The namespace `starfleet` holds the `shuttle` pod, the Secret `practice-token` and the ConfigMap `legacy-settings`, which stores the disposable credential `disposable-v1`. The namespace `outpost` holds the `drifter` pod.

<!-- astrona:playground:renew -->

Open a shell on the VM. You are logged in as the `student` user, and `kubectl` already points at the cluster. Node files and processes belong to root, so run node commands with `sudo`.

```sh
astrona ssh astro-ats-034-playground-020-03
```

## Inspect And Explain

The playground has the ConfigMap `legacy-settings`, which stores a disposable credential in the key `credential`. Check that the key exists without printing its value, and list the Pods:

```sh
kubectl -n starfleet get configmap legacy-settings -o jsonpath='{.data}' | grep -c credential
kubectl -n starfleet get pods -o wide
```

Create a Secret with the same value and a Pod that reads it as a read-only file. Use a Secret, not a ConfigMap, so that Secret-specific controls apply to the value.

Save this as `secret-migrated-credentials.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: migrated-credentials
  namespace: starfleet
type: Opaque
stringData:
  token: disposable-v1
---
apiVersion: v1
kind: Pod
metadata:
  name: migrated-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    volumeMounts:
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: migrated-credentials
      defaultMode: 0400
```

Apply it:

```sh
kubectl apply -f secret-migrated-credentials.yaml
```

## Verify The Result

Wait for the Pod, compare the value inside the container and delete the ConfigMap:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/migrated-reader --timeout=180s
kubectl -n starfleet exec migrated-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1'
kubectl -n starfleet delete configmap legacy-settings
```

Check that no environment variable holds the credential, then check that the ConfigMap is gone. The last command must fail with a `NotFound` error, so run it on its own:

```sh
kubectl -n starfleet exec migrated-reader -- sh -c 'test -z "$(env | grep disposable)"'
kubectl -n starfleet get configmap legacy-settings
```

## Common pitfalls

> [!WARNING]
> - Run the commands in the VM shell, not on your own computer.
> - Create and check the replacement before you delete the original.
> - Do not change the existing `shuttle` pod to hide a mistake in the new Pod.
