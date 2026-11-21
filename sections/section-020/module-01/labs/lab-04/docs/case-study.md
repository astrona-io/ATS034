---
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster. The kube-apiserver runs with `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml`, and that file has one `aescbc` key named `key1`. The namespace `starfleet-034-020-01-04` holds the Secrets `probe-credentials`, `scout-token` and `bridge-api-key`. etcd stores every Secret in the cluster with `key1`.
