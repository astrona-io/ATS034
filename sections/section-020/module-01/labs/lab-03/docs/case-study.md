---
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster. The namespace `starfleet-034-020-01-03` holds the Secrets `probe-credentials` and `scout-token`. The kube-apiserver runs without `--encryption-provider-config`, so etcd stores both Secrets as plain data.
