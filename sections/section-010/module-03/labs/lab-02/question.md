---
exam_objectives:
- Use appropriate pod security standards
---
# Set Cluster-Wide Pod Security Defaults And An Exemption

Allow about 15 minutes for the tasks.

New namespaces in this cluster start with no Pod Security labels, so they accept any Pod. The platform team wants a safe default for every namespace, with one namespace left free for node agents.

## Starting state

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the Pods. The API server runs as a static Pod from the manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`, without the flag `--admission-control-config-file`. The namespaces `starfleet-034-010-03-02` and `node-agents-034-010-03-02` exist and have no Pod Security labels.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-010-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.

## Tasks

1. Write the admission configuration file `/etc/kubernetes/pod-security/admission.yaml` for the `PodSecurity` plugin with these defaults:
   - `enforce` `baseline` at version `v1.35`;
   - `warn` and `audit` `restricted` at version `v1.35`.
2. In the same file, exempt the namespaces `kube-system` and `node-agents-034-010-03-02`.
3. Start the API server with `--admission-control-config-file=/etc/kubernetes/pod-security/admission.yaml`. The API server runs in a container, so it also needs the directory mounted read-only.
4. Do not add Pod Security labels to any namespace. Keep any backup of the manifest outside `/etc/kubernetes/manifests`.

## Check your work

Save a privileged Pod as `pod-privileged.yaml`. It has no namespace, so the same file works in both namespaces:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-check
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

Send it through admission as a server-side dry run in both namespaces. A dry run passes every admission check but stores nothing:

```sh
kubectl -n starfleet-034-010-03-02 create --dry-run=server -f pod-privileged.yaml
kubectl -n node-agents-034-010-03-02 create --dry-run=server -f pod-privileged.yaml
```

The first command must fail with `violates PodSecurity "baseline:v1.35"`. The second must succeed with no Pod Security warning.
