---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate The Encryption-At-Rest Key Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-01-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-01-04`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Confirm the starting state

An `EncryptionConfiguration` is the file that tells the kube-apiserver how to store each resource in etcd. The kube-apiserver encrypts new data with the first key of the first provider. It reads stored data with the key whose name is in the stored prefix, for example `k8s:enc:aescbc:v1:key1:`. This is why the order of the keys matters in a rotation.

Look at the key names in the file and count the Secrets in etcd. etcdctl, the command-line client of etcd, runs inside the etcd container, so `crictl exec` starts it there:

```sh
sudo grep -n 'name:' /etc/kubernetes/enc/enc.yaml
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/ --prefix | grep -a -c 'k8s:enc:aescbc:v1:key1:'
```

In a test run the output was:

```
9:      - name: key1
4
```

The file has one key, `key1`, and etcd stores 4 Secrets with it: the three lab Secrets and one bootstrap token that kubeadm created. Your count can be different if the cluster has more Secrets.

## Add key2 in front of key1

Create a new random 32-byte key and print the current one. Both values go into the new file:

```sh
head -c 32 /dev/urandom | base64
sudo grep 'secret:' /etc/kubernetes/enc/enc.yaml
```

Save this as `encryptionconfiguration-key2.yaml`, with the new key in place of `<NEW_KEY>` and the current key in place of `<OLD_KEY>`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key2
        secret: <NEW_KEY>
      - name: key1
        secret: <OLD_KEY>
  - identity: {}
```

`key2` comes first, so the kube-apiserver writes new data with it. `key1` stays second, so the kube-apiserver can still read the Secrets that etcd stores with `key1`. Copy the file to the node, allow only root to read it, and remove the copy from the home directory:

```sh
sudo cp encryptionconfiguration-key2.yaml /etc/kubernetes/enc/enc.yaml
sudo chmod 600 /etc/kubernetes/enc/enc.yaml
rm encryptionconfiguration-key2.yaml
sudo ls -l /etc/kubernetes/enc
```

In a test run the listing showed `-rw------- 1 root root 319 Nov 21 10:51 enc.yaml`.

## Restart the kube-apiserver

The kube-apiserver reads the `EncryptionConfiguration` only when it starts. The static pod manifest in `/etc/kubernetes/manifests` did not change, so the kubelet does not restart the pod by itself. Stop the kube-apiserver container instead. The kubelet sees the stopped container and starts a new one in the same pod:

```sh
sudo crictl stop "$(sudo crictl ps --name kube-apiserver -q)"
for attempt in $(seq 1 60); do kubectl get --raw=/readyz 2>/dev/null && break; sleep 5; done; echo
```

The first command prints the ID of the stopped container. The loop prints `ok` once the new kube-apiserver answers. In a test run that took about 5 seconds. The loop stops after 5 minutes, so it cannot hang.

Now write a test Secret and count the prefixes in etcd:

```sh
kubectl -n starfleet-034-020-01-04 create secret generic rotation-check --from-literal=value=disposable-check
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/ --prefix | grep -a -c 'k8s:enc:aescbc:v1:key2:'
kubectl -n starfleet-034-020-01-04 delete secret rotation-check
```

In a test run the count was `1`: the new Secret is stored with `key2`. The 4 older Secrets are still stored with `key1`. Do not remove `key1` now. Without it, the kube-apiserver cannot read those Secrets and answers with `no matching key was found for the provided AES transformer`.

## Rewrite every Secret with key2

A new key changes only how the kube-apiserver writes data. Read every Secret and replace it with itself, so the kube-apiserver writes each one again with `key2`:

```sh
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

In a test run the output was:

```
secret/bootstrap-token-r0mvik replaced
secret/bridge-api-key replaced
secret/probe-credentials replaced
secret/scout-token replaced
```

Run the `etcdctl` count again with `key1` in the pattern. It now prints `0`, and the same count with `key2` prints `4`.

## Remove key1 and restart again

Every Secret is now stored with `key2`, so the kube-apiserver no longer needs `key1`. Save this as `encryptionconfiguration-key2-only.yaml`, with the same new key in place of `<NEW_KEY>`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key2
        secret: <NEW_KEY>
  - identity: {}
```

Copy it to the node in the same way, then restart the kube-apiserver so that it drops `key1` from memory:

```sh
sudo cp encryptionconfiguration-key2-only.yaml /etc/kubernetes/enc/enc.yaml
sudo chmod 600 /etc/kubernetes/enc/enc.yaml
rm encryptionconfiguration-key2-only.yaml
sudo crictl stop "$(sudo crictl ps --name kube-apiserver -q)"
for attempt in $(seq 1 60); do kubectl get --raw=/readyz 2>/dev/null && break; sleep 5; done; echo
```

In a test run the loop printed `ok` after about 15 seconds. If you skip the restart, the running kube-apiserver still holds `key1`, and the grader reports `kube-apiserver has not been restarted since the last change to /etc/kubernetes/enc/enc.yaml`.

## Prove the result

Read the three lab Secrets through the API, then look at the start of one stored value in etcd:

```sh
kubectl -n starfleet-034-020-01-04 get secret probe-credentials -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n starfleet-034-020-01-04 get secret scout-token -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n starfleet-034-020-01-04 get secret bridge-api-key -o jsonpath='{.data.key}' | base64 -d; echo
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/starfleet-034-020-01-04/probe-credentials | hexdump -C | head -6
```

In a test run the output was:

```
disposable-probe-password
disposable-scout-token
disposable-bridge-key
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 73 74 61 72 66 6c  65 65 74 2d 30 33 34 2d  |s/starfleet-034-|
00000020  30 32 30 2d 30 31 2d 30  34 2f 70 72 6f 62 65 2d  |020-01-04/probe-|
00000030  63 72 65 64 65 6e 74 69  61 6c 73 0a 6b 38 73 3a  |credentials.k8s:|
00000040  65 6e 63 3a 61 65 73 63  62 63 3a 76 31 3a 6b 65  |enc:aescbc:v1:ke|
00000050  79 32 3a e0 eb 85 10 7a  8f 5f 8c 09 87 99 7b 6a  |y2:....z._....{j|
```

The API still returns all three values, because the kube-apiserver decrypts them with `key2`. etcd stores the Secret with the prefix `k8s:enc:aescbc:v1:key2:`, followed by unreadable bytes. The bytes after the prefix are different in every run.

## Common pitfalls

> [!WARNING]
> Putting `key2` second, after `key1`, means new data is still written with `key1`. The first key is the one that writes.
>
> Removing `key1` before the rewrite makes every Secret stored with `key1` unreadable. The kube-apiserver answers `no matching key was found for the provided AES transformer`, and `/readyz` stays failed. Put `key1` back and restart to recover.
>
> Changing the file without a restart has no effect. The running kube-apiserver keeps the keys it read when it started.
