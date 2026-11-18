---
exam_objectives:
- Manage Kubernetes secrets
---
# Record Secret Access In The Audit Log

Write an audit policy that logs Secrets at `Metadata`, start the kube-apiserver with it and an audit log path, read a Secret as a ServiceAccount, and prove from the log file that the access was recorded without any request or response body.

The task and solution use a VM from the pinned `24.04-cks` image with a one-node kubeadm cluster. The graders read the running kube-apiserver command line, then parse the JSON lines of `/var/log/kubernetes/audit/audit.log` on the node. `audit-enabled` creates and reads its own short-lived Secret and needs a `get` event at level `Metadata` without `requestObject` or `responseObject`. `auditor-read-logged` needs a successful `get` of `probe-credentials` by `system:serviceaccount:starfleet-034-020-03-02:auditor` (directly or through impersonation with `--as`) at the same level. `vm/` holds the scripts astrona pipes into the VM; regenerate them with `python3 scripts/ci/vm-lab.py <this folder>` after you change a lab file. Run `astrona test` on this folder: `vm/install.sh` builds the cluster and runs `bootstrap/setup.sh` in the VM, `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and every outcome must pass.
