---
exam_objectives:
- Manage Kubernetes secrets
---
# Deliver A Secret As An Environment Variable And A File Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-01-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A Secret is a Kubernetes object that holds a small amount of sensitive data, such as a token or a password. A pod receives a Secret in one of two ways. A `secretKeyRef` in `env` copies one key into an environment variable when the container starts. A `secret` volume makes the kubelet, the agent on each node, write every key as a file into the container.

The file mode of a Secret volume comes from `defaultMode`. The value `0400` means read for the owner and no access for anyone else. YAML reads a number that starts with `0` as an octal number, so `0400` is the mode you expect.

Save this as `pod-token-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: token-reader
  namespace: starfleet-034-020-01-01
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
    env:
    - name: PRACTICE_TOKEN
      valueFrom:
        secretKeyRef:
          name: practice-token
          key: token
    volumeMounts:
    - name: credentials
      mountPath: /credentials
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: practice-token
      defaultMode: 0400
```

Apply it:

```sh
kubectl apply -f pod-token-reader.yaml
```

Then check the result. Wait for the pod to be Ready, then compare the two values inside the container and print the file mode:

```sh
kubectl -n starfleet-034-020-01-01 wait --for=condition=Ready pod/token-reader --timeout=180s
kubectl -n starfleet-034-020-01-01 exec token-reader -- sh -c 'test "$PRACTICE_TOKEN" = disposable-v1 && echo match || echo different'
kubectl -n starfleet-034-020-01-01 exec token-reader -- sh -c 'test "$(cat /credentials/token)" = disposable-v1 && echo match || echo different'
kubectl -n starfleet-034-020-01-01 exec token-reader -- stat -L -c %a /credentials/token
```

The two compare commands must print `match`, and the `stat` command must print `400`. The `-L` option matters. The kubelet writes `/credentials/token` as a symbolic link into a hidden folder, and without `-L` the `stat` command shows the mode of the link instead of the file.

When you are done, remove the lab with `astrona destroy ats-034-lab-020-01-01`.

## Common pitfalls

> [!WARNING]
> Do not print the value with `echo $PRACTICE_TOKEN` or `cat`. The output ends up in your terminal history and in logs. Compare the value inside the container instead.
>
> Writing `defaultMode: 400` without the leading `0` gives the decimal number 400, which is the octal mode `0620`. Always write the leading `0`, and check the result with `stat -L`.
