---
exam_objectives:
- Use appropriate pod security standards
---
# Remove Host Networking And A hostPath Volume Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-04" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Pod Security Admission checks Pods, not Deployments. A Deployment that breaks the profile is still stored, and the rejection happens when the ReplicaSet controller tries to create a Pod. The controller records that rejection as a `FailedCreate` event, so start there:

```sh
kubectl -n starfleet-034-010-02-04 get deploy collector
kubectl -n starfleet-034-010-02-04 get events --field-selector reason=FailedCreate -o custom-columns=MSG:.message
```

```text
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
collector   0/1     0            0           2s
MSG
Error creating: pods "collector-6888b77c76-7sbls" is forbidden: violates PodSecurity "baseline:v1.35": host namespaces (hostNetwork=true), hostPath volumes (volume "logs")
```

The event output is shortened to its first message; the controller retries and records the same message several times. It names both broken Baseline rules. `hostNetwork: true` puts the Pod in the network namespace of the node, so the process sees every network interface of the node and can listen on its addresses. A `hostPath` volume mounts a directory of the node filesystem into the container, here the node logs of every Pod. Baseline forbids both because they reach past the Pod into the node.

The fix removes `hostNetwork` and replaces the `hostPath` source with `emptyDir`. An `emptyDir` volume is an empty directory that the kubelet creates for the Pod and deletes with it. The volume name and the mount path stay the same, so the process still writes to `/logs`.

Save this as `deployment-collector.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: collector
  namespace: starfleet-034-010-02-04
spec:
  replicas: 1
  selector:
    matchLabels:
      app: collector
  template:
    metadata:
      labels:
        app: collector
    spec:
      containers:
      - name: collector
        image: docker.io/library/busybox:1.37.0
        command: ["sleep", "infinity"]
        volumeMounts:
        - name: logs
          mountPath: /logs
      volumes:
      - name: logs
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f deployment-collector.yaml
kubectl -n starfleet-034-010-02-04 rollout status deployment/collector --timeout=180s
```

The Deployment controller creates a new ReplicaSet for the changed template, and Pod Security Admission accepts its Pod. Then check the result:

```sh
kubectl -n starfleet-034-010-02-04 get pods -l app=collector -o wide
kubectl -n starfleet-034-010-02-04 exec deploy/collector -- ls -A /logs
kubectl -n starfleet-034-010-02-04 exec deploy/collector -- touch /logs/test-file
```

```text
NAME                         READY   STATUS    RESTARTS   AGE   IP            NODE                                  NOMINATED NODE   READINESS GATES
collector-67ddc8b9b7-gr4qc   1/1     Running   0          0s    10.244.0.12   astro-ats-034-010-dev-control-plane   <none>           <none>
```

This output comes from a test cluster, so the node name in your lab is different. The Pod address `10.244.0.12` comes from the Pod network, not from the node. The `ls` command prints nothing, because the new volume starts empty. The `touch` command also prints nothing, which means the write succeeded.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-02-04`.

## Common pitfalls

> [!WARNING]
> - `hostNetwork: false` and removing the line have the same effect. Leaving `hostNetwork: true` and only fixing the volume still fails Baseline.
> - Do not remove the Pod Security labels of the namespace to make the Pod start. The task is to fix the workload, not the rule.
> - Deleting the volume entry but keeping the `volumeMounts` entry is invalid. The API server rejects a mount that names a volume that does not exist.
