---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Use A NodeRestriction Label For Tenant Placement Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-03-02" || exit 1
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-034-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
```

Keep this connection for the whole task. Each kind node is a container, so `"$engine" exec "$cluster-worker" ...` runs a command on the worker node.

NodeRestriction is an admission plugin of the API server. It limits what a kubelet may change on its own Node object. A kubelet may still set most labels on its own node, but it may not add, change or remove labels with the prefix `node-restriction.kubernetes.io/`. Only a user with the right RBAC (role-based access control) permissions, such as the cluster administrator, can set those labels.

## See the problem first

The kubelet of the worker signs in as the user `system:node:astro-ats-034-lab-030-03-02-worker` in the group `system:nodes`. Check that the kubelet credentials can change the plain label. The `--dry-run=server` flag makes the API server run every check without saving the change:

```sh
"$engine" exec "$cluster-worker" kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node "$cluster-worker" tenant=tenant-x --overwrite --dry-run=server
```

The output is `node/astro-ats-034-lab-030-03-02-worker labeled (server dry run)`. The API server accepts the change, so a node that someone has taken over could give itself the label `tenant=tenant-d` and receive tenant D's Pods.

## Move the workload to the protected label

As the cluster administrator, add the protected label to the worker:

```sh
kubectl label node "$cluster-worker" node-restriction.kubernetes.io/tenant=tenant-d
```

The output is `node/astro-ats-034-lab-030-03-02-worker labeled`. Next, change the Pod template so that it selects only the protected label. Save this as `deployment-tenant-d-app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-d-app
  namespace: tenant-d-034-030-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tenant-d-app
  template:
    metadata:
      labels:
        app: tenant-d-app
    spec:
      nodeSelector:
        node-restriction.kubernetes.io/tenant: tenant-d
      containers:
      - name: app
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep infinity
```

Apply it:

```sh
kubectl apply -f deployment-tenant-d-app.yaml
kubectl -n tenant-d-034-030-03-02 rollout status deployment/tenant-d-app --timeout=180s
```

The Deployment controller creates a new Pod from the changed template and then removes the old one. The rollout ends with `deployment "tenant-d-app" successfully rolled out`. Now no Pod needs the plain label, so remove it. The minus sign after the key removes the label:

```sh
kubectl label node "$cluster-worker" tenant-
```

Then check the result:

```sh
kubectl get node "$cluster-worker" -L tenant,node-restriction.kubernetes.io/tenant
kubectl -n tenant-d-034-030-03-02 get pods -o wide
```

The output (columns shortened) shows the first `TENANT` column (the plain label) empty and the second column (the protected label) with `tenant-d`. The new Pod is `Running` on the worker:

```text
NAME                                 STATUS   ROLES    AGE   VERSION   TENANT   TENANT
astro-ats-034-lab-030-03-02-worker   Ready    <none>   20s   v1.35.0            tenant-d
NAME                            READY   STATUS        ...   NODE
tenant-d-app-5546f598b6-pd28m   1/1     Running       ...   astro-ats-034-lab-030-03-02-worker
tenant-d-app-5b8fbfdc4b-pvskz   1/1     Terminating   ...   astro-ats-034-lab-030-03-02-worker
```

The old Pod shows `Terminating` for about 30 seconds. The `sleep` process does not stop on the stop signal, so the kubelet waits for the grace period before it kills the container.

## Prove that the kubelet cannot change the protected label

Run the same kind of change with the kubelet credentials, this time on the protected label:

```sh
"$engine" exec "$cluster-worker" kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node "$cluster-worker" node-restriction.kubernetes.io/tenant=tenant-x --overwrite
```

The API server refuses it:

```text
Error from server (Forbidden): nodes "astro-ats-034-lab-030-03-02-worker" is forbidden: is not allowed to modify labels: node-restriction.kubernetes.io/tenant
```

The NodeRestriction admission plugin wrote this error. RBAC allowed the request, because nodes may update their own Node object. The admission plugin then checked the label prefix and stopped the change.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-03-02`.

## Common pitfalls

> [!WARNING]
> Removing the plain label before the rollout ends leaves the old Pod without a matching node. Change the Deployment first, wait for the rollout, then remove the label.
>
> NodeRestriction protects only labels with the prefix `node-restriction.kubernetes.io/`. A plain `tenant` label stays open to every kubelet, even when NodeRestriction is on.
>
> A Pod that keeps the plain selector next to the protected one still matches only nodes with both labels. The task asks for the protected label only.
