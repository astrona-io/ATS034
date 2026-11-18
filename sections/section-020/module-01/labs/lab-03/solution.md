---
exam_objectives:
- Manage Kubernetes secrets
---
# Encrypt Secrets At Rest In etcd Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-01-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-01-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Confirm the finding

etcd is the key-value database that stores every Kubernetes object. The kube-apiserver is the only component that writes to it. Without an encryption configuration, the kube-apiserver writes a Secret as a plain object, so its value is readable in the etcd data. etcdctl, the command-line client of etcd, runs inside the etcd container, so `crictl exec` starts it there:

```sh
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/starfleet-034-020-01-03/probe-credentials | grep -a -c disposable
```

The command counts the lines that hold the plain value. Any number above `0` means etcd stores the Secret as plain data.

## Write the encryption configuration

An `EncryptionConfiguration` tells the kube-apiserver how to store each resource. The kube-apiserver encrypts new data with the first provider in the list. It reads stored data with whichever provider matches it. `aescbc` encrypts with AES (Advanced Encryption Standard) in CBC (cipher block chaining) mode and a 32-byte key. `identity` stores data without encryption, so it must come last.

Create a new random key and print it once:

```sh
head -c 32 /dev/urandom | base64
```

Save this as `encryptionconfiguration.yaml`, with your key in place of `<KEY>`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <KEY>
  - identity: {}
```

Copy it to the node directory and allow only root to read it:

```sh
sudo mkdir -p /etc/kubernetes/enc
sudo cp encryptionconfiguration.yaml /etc/kubernetes/enc/enc.yaml
sudo chmod 600 /etc/kubernetes/enc/enc.yaml
sudo ls -l /etc/kubernetes/enc
rm encryptionconfiguration.yaml
```

The listing shows `-rw-------` and the owner `root`. The last line removes the copy with the key from the home directory.

## Change the kube-apiserver manifest

The kubelet watches `/etc/kubernetes/manifests` and starts every file in it as a static pod. Keep the backup in another directory, so the kubelet does not start it as a second API server:

```sh
sudo mkdir -p /root/backup
sudo cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Make three changes. Add the flag to the list under `command`, add a `volumeMounts` entry to the container, and add a `hostPath` volume to the pod. A `hostPath` volume mounts a directory of the node into the container. Then compare the result with the backup:

```sh
sudo diff /root/backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

In a test run the diff showed these three additions (the line numbers can differ):

```
41a42
>     - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
81a83,85
>     - mountPath: /etc/kubernetes/enc
>       name: enc
>       readOnly: true
103a108,111
>   - hostPath:
>       path: /etc/kubernetes/enc
>       type: DirectoryOrCreate
>     name: enc
```

When you save the file, the kubelet stops the old API server and starts a new one. The API is not available for a short time, so wait until it answers again:

```sh
until kubectl get --raw=/readyz 2>/dev/null; do sleep 5; done; echo
ps -ef | grep -o -- '--encryption-provider-config=[^ ]*'
```

The first command prints `ok` once the API server is back. In a test run that took about 40 seconds. The second command shows the flag on the running process. If the API server does not come back after a few minutes, read the container log with `sudo crictl ps -a --name kube-apiserver` and `sudo crictl logs <ID>`, fix the manifest, or copy the backup back.

## Rewrite the existing Secrets

The new configuration changes only how the kube-apiserver writes data. Secrets that were stored before stay plain until something writes them again. Read every Secret and replace it with itself, so the kube-apiserver writes each one with `aescbc`:

```sh
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

The command prints one `replaced` line for each Secret. Then check the result in etcd:

```sh
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/starfleet-034-020-01-03/probe-credentials | hexdump -C | head -5
kubectl -n starfleet-034-020-01-03 get secret probe-credentials -o jsonpath='{.data.password}' | base64 -d; echo
```

The hexdump now shows `k8s:enc:aescbc:v1:key1:` after the key name, followed by unreadable bytes. The API still returns `disposable-probe-password`, because the kube-apiserver decrypts the data before it answers. Run the same checks for `scout-token`.

## Common pitfalls

> [!WARNING]
> A wrong path in the flag or a missing volume mount stops the kube-apiserver from starting. Keep the backup outside `/etc/kubernetes/manifests`, and read the container log with `crictl` when the API does not come back.
>
> Turning on encryption does not encrypt the data that is already stored. Without the `kubectl replace` step, old Secrets stay plain in etcd.
>
> Putting `identity` first means new data is still written as plain data. The first provider is the one that writes.
