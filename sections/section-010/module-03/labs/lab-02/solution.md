---
exam_objectives:
- Use appropriate pod security standards
---
# Set Cluster-Wide Pod Security Defaults And An Exemption Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-010-03-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-034-lab-010-03-02
```

Keep this shell for the whole task. Every script of the lab refuses to run against another context.

## Look at the starting state

Pod Security admission is the admission plugin in the API server that checks every new Pod against a Pod Security Standard. A namespace label selects the standard for one namespace. Without labels and without a configuration file, the plugin uses `privileged`, which allows everything. The two namespaces have only the label that Kubernetes adds itself, and the API server has no configuration file:

```sh
kubectl get namespace starfleet-034-010-03-02 node-agents-034-010-03-02 --show-labels
sudo grep -c admission-control-config-file /etc/kubernetes/manifests/kube-apiserver.yaml
```

```text
NAME                        STATUS   AGE   LABELS
starfleet-034-010-03-02     Active   4s    kubernetes.io/metadata.name=starfleet-034-010-03-02
node-agents-034-010-03-02   Active   4s    kubernetes.io/metadata.name=node-agents-034-010-03-02
0
```

Save the privileged test Pod as `pod-privileged.yaml`:

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

Send it through admission as a server-side dry run. A dry run passes every admission check but stores nothing:

```sh
kubectl -n starfleet-034-010-03-02 create --dry-run=server -f pod-privileged.yaml
```

```text
pod/privileged-check created (server dry run)
```

The API server admits a privileged Pod in a namespace without labels. The cluster needs a default that applies when a namespace has no label.

## Write the admission configuration

The API server reads plugin settings from an `AdmissionConfiguration` file. For the `PodSecurity` plugin, the file holds a `PodSecurityConfiguration` with two parts. `defaults` gives the mode and version that apply when a namespace has no label for that mode. `exemptions` lists users, RuntimeClasses or namespaces that the plugin does not check at all. Save this as `admission.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: baseline
      enforce-version: v1.35
      audit: restricted
      audit-version: v1.35
      warn: restricted
      warn-version: v1.35
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces:
      - kube-system
      - node-agents-034-010-03-02
```

The file belongs to root on the node. `install -D` creates the directory and copies the file:

```sh
sudo install -D -m 0644 admission.yaml /etc/kubernetes/pod-security/admission.yaml
sudo ls -l /etc/kubernetes/pod-security
```

```text
total 4
-rw-r--r-- 1 root root 505 Nov 18 12:19 admission.yaml
```

## Point the API server at the file

The kubelet runs the API server as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`. It watches that directory and restarts the API server when the file changes. Keep a backup outside the manifests directory first, because the kubelet would try to run a second copy that sits inside it:

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

The manifest needs three changes. The API server runs in a container, so it sees a node file only through a volume:

1. Under `- kube-apiserver` in the command list, add `- --admission-control-config-file=/etc/kubernetes/pod-security/admission.yaml`.
2. Under `volumeMounts:`, add a mount of `/etc/kubernetes/pod-security` named `pod-security`, with `readOnly: true`.
3. Under `volumes:`, add a `hostPath` volume named `pod-security` for the path `/etc/kubernetes/pod-security`.

After the edit, check the changed places. The output below is shortened to the lines you added; `grep -A4` also prints the four lines after each match:

```sh
sudo grep -n -A4 -E 'admission-control-config-file|name: pod-security|mountPath: /etc/kubernetes/pod-security' /etc/kubernetes/manifests/kube-apiserver.yaml
```

```text
15:    - --admission-control-config-file=/etc/kubernetes/pod-security/admission.yaml
83:    - mountPath: /etc/kubernetes/pod-security
84:      name: pod-security
85-      readOnly: true
111:    name: pod-security
```

The volume at the end of the file looks like this:

```yaml
  - hostPath:
      path: /etc/kubernetes/pod-security
      type: DirectoryOrCreate
    name: pod-security
```

Save the file. The kubelet stops the old API server and starts a new one, so `kubectl` fails for up to about a minute. Wait until the API server reports ready, then check that the new process has the flag:

```sh
kubectl get --raw=/readyz; echo
ps -eo args | grep -o -- '--admission-control-config-file=[^ ]*' | head -1
```

```text
ok
--admission-control-config-file=/etc/kubernetes/pod-security/admission.yaml
```

## Check the result

Send the privileged Pod again to both namespaces:

```sh
kubectl -n starfleet-034-010-03-02 create --dry-run=server -f pod-privileged.yaml
kubectl -n node-agents-034-010-03-02 create --dry-run=server -f pod-privileged.yaml
```

```text
Error from server (Forbidden): error when creating "pod-privileged.yaml": pods "privileged-check" is forbidden: violates PodSecurity "baseline:v1.35": privileged (container "check" must not set securityContext.privileged=true)
pod/privileged-check created (server dry run)
```

The `starfleet-034-010-03-02` namespace still has no Pod Security label, so the default `enforce: baseline` applies and rejects the Pod. The `node-agents-034-010-03-02` namespace is exempt, so the plugin skips the Pod and prints no warning.

A Pod without any security settings passes Baseline, and the `warn` default shows what it would still need for Restricted. Save it as `pod-plain.yaml`, with the same content as the privileged Pod but the name `plain-check` and no `securityContext`, then send it:

```sh
kubectl -n starfleet-034-010-03-02 create --dry-run=server -f pod-plain.yaml
```

```text
Warning: would violate PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (container "check" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "check" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "check" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "check" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
pod/plain-check created (server dry run)
```

The defaults now protect every namespace that has no labels, and a namespace label still overrides the default for its own mode. When you are done, remove the lab with `astrona destroy ats-034-lab-010-03-02`.

## Common pitfalls

> [!WARNING]
> - Adding only the flag is not enough. Without the volume and the mount, the API server container cannot read the file and does not start.
> - A backup copy inside `/etc/kubernetes/manifests` becomes a second static Pod. Keep backups in your home directory.
> - The defaults apply only where a namespace has no label for that mode. Do not add labels to the two namespaces, or the labels decide instead of the file.
> - An exempt namespace skips all three modes. It gets no enforcement, no warning and no audit annotation.
