---
exam_objectives:
- Use appropriate pod security standards
---
# Run A Deployment As A Non-Root User Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Start by looking at the identity of the running process and at the reply that `shuttle` gets today:

```sh
kubectl -n starfleet-034-010-02-01 exec deploy/probe -- id
kubectl -n starfleet-034-010-02-01 exec shuttle -- wget -q -T 3 -O- http://probe/
```

```text
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
version=v1 host=probe-7db6ffd7d6-hh46s greeting=hello
```

The process runs as root, because the image declares no user. Two fields fix this. The field `runAsUser: 1000` chooses the user ID of the process. The field `runAsNonRoot: true` is a check that the kubelet, the node agent that starts containers, runs before it starts a container: if the final user ID is 0, the kubelet refuses to start it. With `runAsNonRoot` alone, this image would not start at all, because the image gives no user and the default is root. Both fields go in the Pod-level `securityContext` of the template, so they apply to every container in the Pod.

Save this as `deployment-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet-034-010-02-01
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
      release: probe
  template:
    metadata:
      labels:
        app: probe
        release: probe
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v1
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 2
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 128Mi
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
      volumes:
      - name: app
        configMap:
          name: probe-code
```

Apply it:

```sh
kubectl apply -f deployment-probe.yaml
kubectl -n starfleet-034-010-02-01 rollout status deployment/probe --timeout=180s
```

The Deployment controller creates a new ReplicaSet for the changed template and replaces the two old Pods one by one. The rollout ends with `deployment "probe" successfully rolled out`. Then check the result:

```sh
kubectl -n starfleet-034-010-02-01 exec deploy/probe -- id
kubectl -n starfleet-034-010-02-01 exec shuttle -- wget -q -T 3 -O- http://probe/
```

```text
uid=1000 gid=0(root) groups=0(root)
version=v1 host=probe-7f89684c8c-8wc7m greeting=hello
```

The process now runs as user ID 1000. The group ID stays 0, because the task does not ask for `runAsGroup`. The server still works: it listens on port 8080, which is above 1024, so an ordinary user may open it. It also only reads its code from the ConfigMap volume. The `host` field names a Pod of the new ReplicaSet, so the Service sends the request to a Pod that runs as user 1000.

When you are done, remove the lab with `astrona destroy ats-034-lab-010-02-01`.

## Common pitfalls

> [!WARNING]
> - `runAsNonRoot: true` without `runAsUser` makes the new Pods fail with `CreateContainerConfigError`, because this image runs as root by default. The old Pods keep serving, so the Service still answers, but the rollout never finishes.
> - Do not change the labels of the Pod template. The Service selects `app: probe` and `release: probe`, and the Deployment selector cannot change.
> - Editing a running Pod does not work. The security settings of a container are fixed when it starts, so change the template and let the Deployment replace the Pods.
