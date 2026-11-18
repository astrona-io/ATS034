---
exam_objectives:
- Manage Kubernetes secrets
---
# Give A ServiceAccount An Image Pull Secret

Allow about 10 minutes for the tasks.

Pods in `starfleet-034-020-02-01` will soon pull images from the private registry `registry.example.test`. Prepare the registry credential once, so that every pod that runs as the ServiceAccount `puller` receives it without listing it itself.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-020-02-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

The namespace `starfleet-034-020-02-01` runs the pod `shuttle`. It has no image pull Secret and no ServiceAccount other than `default`. The registry `registry.example.test` does not exist; the lab only checks the Kubernetes objects.

## Tasks

1. Create the Secret `registry-pull` in `starfleet-034-020-02-01` with the type `kubernetes.io/dockerconfigjson`. It must hold a login for the server `registry.example.test` with the user name `practice` and the password `disposable-pull`.
2. Create the ServiceAccount `puller` in the same namespace. It must list `registry-pull` in its `imagePullSecrets`.
3. Create the pod `pull-check` in the same namespace with `serviceAccountName: puller` and `restartPolicy: Never`. Use one container with the image `docker.io/library/busybox:1.37.0` and the command `sleep 3600`. Do not add `imagePullSecrets` to the pod yourself.
4. The pod `pull-check` must be Ready, and its `spec.imagePullSecrets` must contain `registry-pull`.

## Check your work

```sh
kubectl -n starfleet-034-020-02-01 get secret registry-pull -o jsonpath='{.type}{"\n"}'
kubectl -n starfleet-034-020-02-01 get serviceaccount puller -o jsonpath='{.imagePullSecrets[*].name}{"\n"}'
kubectl -n starfleet-034-020-02-01 get pod pull-check -o jsonpath='{.spec.imagePullSecrets[*].name}{"\n"}'
```

The commands must print `kubernetes.io/dockerconfigjson`, `registry-pull` and `registry-pull`.
