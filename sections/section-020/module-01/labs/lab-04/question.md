---
exam_objectives:
- Manage Kubernetes secrets
---
# Rotate The Encryption-At-Rest Key

Allow about 15 minutes for the tasks.

The `starfleet` cluster encrypts its Secrets in etcd with one key, `key1`. A security review says `key1` was copied into an old backup and must be retired. Replace it with a new key, `key2`, without losing any Secret.

## Starting state

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. etcd is the key-value database that stores every Kubernetes object.

The kube-apiserver runs with `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`. That `EncryptionConfiguration` has one `aescbc` provider with one key named `key1`, then `identity: {}`. The namespace `starfleet-034-020-01-04` holds the Secrets `probe-credentials`, `scout-token` and `bridge-api-key`. etcd stores every Secret in the cluster with `key1`.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-01-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-01-04`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Add a new random 32-byte `aescbc` key named `key2` to `/etc/kubernetes/enc/enc.yaml`, as the first key. Keep `key1` in the file for now. Restart the kube-apiserver so that it encrypts new Secrets with `key2`.
2. Write all existing Secrets in the cluster again, so that etcd stores every Secret with `key2`.
3. Remove `key1` from the file and restart the kube-apiserver again. The file stays owned by root with the mode `600`. All three Secrets in `starfleet-034-020-01-04` must still return their values through the API.

## Check your work

etcdctl, the command-line client of etcd, is not installed on the node. It runs inside the etcd container. This command counts the Secrets in etcd that are still stored with `key1`:

```sh
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/ --prefix | grep -a -c 'k8s:enc:aescbc:v1:key1:'
```

At the start it prints the number of Secrets in the cluster. After the task it prints `0`. The grader also creates its own short-lived Secret and checks that etcd stores it with `key2`.
