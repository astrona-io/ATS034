---
exam_objectives:
- Manage Kubernetes secrets
---
# Record Secret Access In The Audit Log

Allow about 15 minutes for the tasks.

The security team must know who reads the `probe-credentials` Secret in `starfleet-034-020-03-02`. The cluster writes no audit log yet. Turn on auditing so that every Secret access is recorded, and make sure the log never holds a Secret value.

## Starting state

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. The namespace `starfleet-034-020-03-02` holds the Secret `probe-credentials` and the ServiceAccount `auditor`. A Role and a RoleBinding already allow `auditor` to `get` that one Secret. The kube-apiserver runs without any audit flags, so it writes no audit log.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Create the audit policy file `/etc/kubernetes/audit/policy.yaml`. It must log requests for `secrets` at the level `Metadata`, so that no request body or response body reaches the log.
2. Start the kube-apiserver with `--audit-policy-file=/etc/kubernetes/audit/policy.yaml` and `--audit-log-path=/var/log/kubernetes/audit/audit.log`. Mount the policy file and the log directory into the kube-apiserver static pod at the same paths. Keep any backup of the manifest outside `/etc/kubernetes/manifests`.
3. After the API server is back, read the Secret `probe-credentials` as the ServiceAccount `auditor`, so the audit log records this access.

## Check your work

The audit log is a file on the node with one JSON object per line. This command prints the newest event for the Secret:

```sh
sudo grep '"name":"probe-credentials"' /var/log/kubernetes/audit/audit.log | tail -1
```

The event must show `"level":"Metadata"`, the verb `get` and the user `system:serviceaccount:starfleet-034-020-03-02:auditor`. It must not contain the fields `requestObject` or `responseObject`. The grader also reads one Secret of its own and checks that this access reaches the log at the level `Metadata`.
