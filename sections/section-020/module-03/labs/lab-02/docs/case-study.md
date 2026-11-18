---
exam_objectives:
- Manage Kubernetes secrets
---
# Starting Environment

The lab VM runs a one-node kubeadm cluster. The namespace `starfleet-034-020-03-02` holds the Secret `probe-credentials`, the ServiceAccount `auditor`, and the Role `secret-reader` with the RoleBinding `auditor-secret-reader` that let `auditor` get that one Secret. The kube-apiserver runs without `--audit-policy-file` and `--audit-log-path`, so no audit log exists.
