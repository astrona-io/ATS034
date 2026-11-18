---
exam_objectives:
- Use appropriate pod security standards
---
# Prerequisites

Use a host shell with astrona installed. The lab runs a one-node Kubernetes cluster built with kubeadm inside its own virtual machine (VM). Open a shell on the VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-034-lab-010-03-02`. Every script of the lab refuses to run against another context.
