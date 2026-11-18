---
exam_objectives:
- Manage Kubernetes secrets
---
# Encrypt Secrets At Rest In etcd

Allow about 20 minutes for the tasks.

The `starfleet` cluster stores its Secrets in etcd as plain data. Anyone who reads the etcd data or a backup of it can read the `probe-credentials` and `scout-token` values. Turn on encryption at rest and make sure the existing Secrets are encrypted too.

## Starting state

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. etcd is the key-value database that stores every Kubernetes object. The namespace `starfleet-034-020-01-03` holds the Secrets `probe-credentials` and `scout-token`. The kube-apiserver runs without an encryption configuration, so etcd holds both Secrets as plain data.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-01-03
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-01-03`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Create the file `/etc/kubernetes/enc/enc.yaml` with an `EncryptionConfiguration` for the resource `secrets`. The first provider must be `aescbc` or `secretbox` with a new random 32-byte key. Add `identity: {}` as the last provider, so the API server can still read data that is not yet encrypted.
2. The file must be owned by root with the mode `600`.
3. Start the kube-apiserver with `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`. Mount the directory `/etc/kubernetes/enc` into the kube-apiserver static pod at the same path. Keep any backup of the manifest outside `/etc/kubernetes/manifests`.
4. Write all existing Secrets again, so that etcd stores `probe-credentials` and `scout-token` encrypted. Both must still return their values through the API.

## Check your work

etcdctl, the command-line client of etcd, is not installed on the node. It runs inside the etcd container. This command prints the start of the stored data of one Secret:

```sh
sudo crictl exec "$(sudo crictl ps --name etcd -q)" etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/starfleet-034-020-01-03/probe-credentials | hexdump -C | head -5
```

After the task, the data starts with `k8s:enc:aescbc:v1:` (or `k8s:enc:secretbox:v1:`) instead of `k8s` followed by the plain object. The grader also creates its own short-lived Secret and checks that etcd stores it encrypted.
