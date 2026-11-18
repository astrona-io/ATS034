---
exam_objectives:
- Use appropriate pod security standards
---
# Roll Out Restricted Using A Dry-Run Inventory Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-03-01" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

Pod Security Admission is the admission controller in the API server that checks every new Pod against a Pod Security Standard. A namespace label such as `pod-security.kubernetes.io/enforce=restricted` turns it on for that namespace. When you add or change an `enforce` label, the API server also checks the Pods that already run there and prints a warning for each one that breaks the new level. It never stops those Pods, but it rejects the next Pod a controller tries to create.

That check also runs on a server-side dry run, so a dry run of the label is an inventory that changes nothing. Run it on all three namespaces:

```sh
for namespace in bridge-034-010-03-01 starfleet-034-010-03-01 outpost-034-010-03-01; do
  kubectl label --dry-run=server --overwrite namespace "$namespace" \
    pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
done
```

```text
namespace/bridge-034-010-03-01 labeled (server dry run)
Warning: existing pods in namespace "starfleet-034-010-03-01" violate the new PodSecurity enforce level "restricted:v1.35"
Warning: shuttle-548b46fd59-mx7ln: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/starfleet-034-010-03-01 labeled (server dry run)
Warning: existing pods in namespace "outpost-034-010-03-01" violate the new PodSecurity enforce level "restricted:v1.35"
Warning: drifter: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/outpost-034-010-03-01 labeled (server dry run)
```

The API server found no problem in `bridge-034-010-03-01`. The `shuttle` and `drifter` Pods break four Restricted rules each. Enforcing Restricted there would leave them running for now, but the next Pod of `shuttle` (after a rollout or a node failure) would be rejected.

Enforce Restricted where the inventory was clean:

```sh
kubectl label --overwrite namespace bridge-034-010-03-01 \
  pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
```

Set only the `warn` mode on the two other namespaces. The `warn` mode admits the Pod and returns the list of problems to the client that sent the request:

```sh
for namespace in starfleet-034-010-03-01 outpost-034-010-03-01; do
  kubectl label --overwrite namespace "$namespace" \
    pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/warn-version=v1.35
done
```

Then check the result. Save this as `pod-plain-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: plain-check
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Send it through admission as a dry run in one namespace of each kind:

```sh
kubectl -n bridge-034-010-03-01 create --dry-run=server -f pod-plain-check.yaml
kubectl -n starfleet-034-010-03-01 create --dry-run=server -f pod-plain-check.yaml
```

```text
Error from server (Forbidden): error when creating "pod-plain-check.yaml": pods "plain-check" is forbidden: violates PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (container "check" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "check" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "check" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "check" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
Warning: would violate PodSecurity "restricted:v1.35": allowPrivilegeEscalation != false (container "check" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "check" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "check" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "check" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
pod/plain-check created (server dry run)
```

The enforce mode in `bridge-034-010-03-01` rejects the Pod. The warn mode in `starfleet-034-010-03-01` admits it and lists the same four problems, which is the work list for the team. Finally, confirm the labels:

```sh
kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn | grep 034-010-03-01
```

```text
bridge-034-010-03-01        Active   5s    restricted   
outpost-034-010-03-01       Active   5s                 restricted
starfleet-034-010-03-01     Active   5s                 restricted
```

The `bridge` namespace enforces Restricted, and the two others only warn. When their teams fix the four fields, the same dry run of the enforce label comes back clean, and you can enforce Restricted there too.
