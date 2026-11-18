---
exam_objectives:
- Use appropriate pod security standards
---
# Starting Environment

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the Pods. The API server runs as a static Pod from the manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`, without the flag `--admission-control-config-file`. The namespaces `starfleet-034-010-03-02` and `node-agents-034-010-03-02` exist and have no Pod Security labels.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-010-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Node files belong to root, so run node commands with `sudo`. They change only the lab VM, not your own computer.
