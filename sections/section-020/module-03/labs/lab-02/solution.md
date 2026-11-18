---
exam_objectives:
- Manage Kubernetes secrets
---
# Record Secret Access In The Audit Log Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-020-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-020-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files and processes belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Confirm the finding

The kube-apiserver writes an audit log only when it starts with the flag `--audit-log-path`, and it uses only the rules of the file named by `--audit-policy-file`. Look for both flags in the running process:

```sh
ps -ef | grep -o -- '--audit-[a-z-]*=[^ ]*'
```

The command prints nothing, so the API server records no access to any Secret yet.

## Write the audit policy

An audit policy is a file with a list of rules. The API server checks the rules in order, and the first rule that matches a request sets its level. The level `Metadata` records who made the request, the verb, the object and the result, but no request body and no response body. A Secret value travels in those bodies, so `Metadata` is the level that records access without recording values.

Save this as `policy-audit.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets
    - configmaps
- level: Metadata
```

The first rule covers Secrets and ConfigMaps, because credentials also end up in ConfigMaps. The last rule has no resource list, so it records the metadata of every other request. `omitStages` drops the `RequestReceived` stage, so each request writes one event when the response is complete instead of two.

Install the file where the task asks for it, readable only by root, and create the log directory:

```sh
sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
sudo install -m 600 policy-audit.yaml /etc/kubernetes/audit/policy.yaml
```

## Change the kube-apiserver static pod

The kubelet runs the kube-apiserver from the static pod manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`. The kubelet watches that directory, so a backup inside it would start a second API server. Keep the backup in `/root/backup`, then edit the manifest:

```sh
sudo mkdir -p /root/backup
sudo cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

The API server runs in a container, so it sees a node file only through a volume. Make three changes. Add the flags under `- kube-apiserver` in the `command` list:

```yaml
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxbackup=2
```

Add the two mounts under `volumeMounts:` of the container:

```yaml
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit
      name: audit-log
```

Add the two `hostPath` volumes under `volumes:` of the pod:

```yaml
  - hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-log
```

`--audit-log-maxage` and `--audit-log-maxbackup` make the API server delete old log files, so the log cannot fill the disk. The log directory is not read-only, because the API server writes to it.

## Wait for the API server

When you save the file, the kubelet stops the old kube-apiserver container and starts a new one. The API server is unreachable for about a minute. Wait until it answers, then look at the flags again:

```sh
until kubectl get --raw=/readyz 2>/dev/null; do sleep 5; done; echo
ps -ef | grep -o -- '--audit-[a-z-]*=[^ ]*'
```

The second command now prints the four audit flags. If the API server does not come back after two or three minutes, read the container logs with `sudo crictl ps -a --name kube-apiserver` and `sudo crictl logs <container-id>`. A wrong path in the policy flag or a missing volume is the usual cause.

## Read the Secret as auditor

The `--as` flag sends the request as another identity. This is impersonation: the API server checks the permissions of `auditor`, not your own, and the audit event names both users. Read the Secret as the ServiceAccount:

```sh
kubectl -n starfleet-034-020-03-02 get secret probe-credentials --as=system:serviceaccount:starfleet-034-020-03-02:auditor
```

The command lists the Secret, because the existing Role allows `get` on `probe-credentials`.

## Check the audit event

Each audit event is one JSON line. Print the newest event for the Secret in a readable form with `jq`, a JSON command-line tool:

```sh
sudo grep '"name":"probe-credentials"' /var/log/kubernetes/audit/audit.log | tail -1 | jq .
```

Check these fields in the event. `level` is `Metadata`, `verb` is `get` and `stage` is `ResponseComplete`. `impersonatedUser.username` is `system:serviceaccount:starfleet-034-020-03-02:auditor`, and `user.username` is the administrator who sent the request. `responseStatus.code` is `200`. The event has no `requestObject` and no `responseObject`, so the value of the Secret is not in the log. The last check proves it across the whole file:

```sh
sudo grep -c disposable /var/log/kubernetes/audit/audit.log
```

The command prints `0`. No event holds the value `disposable-probe-password`.
