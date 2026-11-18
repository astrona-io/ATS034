---
exam_objectives:
- Use appropriate pod security standards
---
# Admit A Node Agent And Protect Pod Security Labels Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-03-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A Deployment does not create Pods itself. The ReplicaSet controller creates them, and Pod Security Admission in the API server checks each Pod it sends. Look at the ReplicaSet and its events:

```sh
kubectl -n node-agents-034-010-03-03 get deployment,replicaset
kubectl -n node-agents-034-010-03-03 get events --field-selector reason=FailedCreate -o custom-columns=MSG:.message --no-headers | head -1
```

```text
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/log-agent   0/1     0            0           1s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/log-agent-6b697b8dc9   1         0         0       1s
Error creating: pods "log-agent-6b697b8dc9-kkg45" is forbidden: violates PodSecurity "baseline:v1.35": hostPath volumes (volume "node-logs")
```

The Baseline profile forbids `hostPath` volumes, because a `hostPath` volume gives the container files of the node. A log agent needs exactly that, so this namespace must be exempt from Baseline. The Privileged profile allows everything. The `warn` and `audit` modes on Baseline keep every privileged Pod visible: `warn` returns a message to the client, and `audit` adds an annotation to the event in the API server audit log. Set all three modes in one command:

```sh
kubectl label --overwrite namespace node-agents-034-010-03-03 \
  pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/enforce-version=v1.35 \
  pod-security.kubernetes.io/warn=baseline pod-security.kubernetes.io/warn-version=v1.35 \
  pod-security.kubernetes.io/audit=baseline pod-security.kubernetes.io/audit-version=v1.35
```

The ReplicaSet controller retries a failed create with a growing delay. A restart of the Deployment makes it create a Pod now:

```sh
kubectl -n node-agents-034-010-03-03 rollout restart deployment/log-agent
kubectl -n node-agents-034-010-03-03 rollout status deployment/log-agent --timeout=180s
kubectl -n node-agents-034-010-03-03 exec deploy/log-agent -- ls /host-logs
```

```text
deployment "log-agent" successfully rolled out
alternatives.log
containers
pods
```

The output is shortened to the last line of the rollout. The agent now lists `/var/log` of the node.

A namespace label is only as strong as the list of accounts that can change it. Any subject that can `update` or `patch` namespaces can set `enforce=privileged` on its own namespace and then run a privileged Pod there. Check the `deployer` ServiceAccount and find the binding that gives it that right:

```sh
kubectl auth can-i patch namespaces --as=system:serviceaccount:starfleet-034-010-03-03:deployer
kubectl get clusterrolebindings -o wide | grep deployer
```

```text
Warning: resource 'namespaces' is not namespace scoped

yes
deployer-namespace-labeler-034-010-03-03                        ClusterRole/namespace-labeler-034-010-03-03                                        2s                                                                                       starfleet-034-010-03-03/deployer
```

Remove the ClusterRoleBinding. The Role and RoleBinding in `starfleet-034-010-03-03` stay, so the account keeps its normal work:

```sh
kubectl delete clusterrolebinding deployer-namespace-labeler-034-010-03-03
```

Then check the result:

```sh
kubectl auth can-i patch namespaces --as=system:serviceaccount:starfleet-034-010-03-03:deployer
kubectl auth can-i create deployments -n starfleet-034-010-03-03 --as=system:serviceaccount:starfleet-034-010-03-03:deployer
kubectl label --overwrite --dry-run=server namespace starfleet-034-010-03-03 pod-security.kubernetes.io/enforce=privileged \
  --as=system:serviceaccount:starfleet-034-010-03-03:deployer
```

```text
Warning: resource 'namespaces' is not namespace scoped

no
yes
Error from server (Forbidden): namespaces "starfleet-034-010-03-03" is forbidden: User "system:serviceaccount:starfleet-034-010-03-03:deployer" cannot get resource "namespaces" in API group "" in the namespace "starfleet-034-010-03-03"
```

The API server now refuses the label change for `deployer`, and the account can still create Deployments. Only the cluster administrator can now change the Pod Security level of a namespace.
