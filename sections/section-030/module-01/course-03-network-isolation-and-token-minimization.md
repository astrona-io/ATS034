---
draft: true
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Network Isolation And Token Minimization

By default every Pod in a Kubernetes cluster can open a connection to every other Pod and every Service, in any namespace. A compromised Pod in one tenant can scan and call the workloads of all the others. A compromised Pod also carries a credential: Kubernetes mounts a ServiceAccount token into every Pod, and that token can call the API server. This part removes both defaults: it blocks the network with a `NetworkPolicy`, and it stops the token from being mounted when a Pod does not need it.

## NetworkPolicy in three rules

A **NetworkPolicy** is a namespaced object that selects Pods and lists the traffic allowed to or from them. The network plugin enforces it. The plugin is the software that gives Pods their IP addresses, called the CNI plugin (Container Network Interface). If the plugin does not support `NetworkPolicy`, the API accepts the object and nothing changes. The playground uses Calico, which enforces it.

Three rules decide the result:

1. A Pod that no policy selects accepts and sends all traffic.
2. When a policy selects a Pod and lists `Ingress` in `policyTypes`, the Pod accepts only the incoming traffic that some selecting policy allows. The same applies to `Egress` and outgoing traffic.
3. Policies only add allowances. There is no deny rule, and the order of policies does not matter.

A policy with an empty `podSelector` selects every Pod in its namespace. If it lists a policy type and no rules, it allows nothing in that direction. That is the **default-deny** policy.

Traffic to a Service is rewritten to a Pod address before the plugin checks the policy. A rule must therefore name the port the Pod listens on, not the port of the Service.

## Show the default, then deny it

Create a namespace with two Pods: `token-default`, which uses the defaults, and `token-off`, which turns off the token mount. Save this as `pods-network-demo.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: network-demo
---
apiVersion: v1
kind: Pod
metadata:
  name: token-default
  namespace: network-demo
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: token-off
  namespace: network-demo
spec:
  automountServiceAccountToken: false
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "3600"]
```

Apply it and wait for both Pods:

```sh
kubectl apply -f pods-network-demo.yaml
kubectl -n network-demo wait --for=condition=Ready pod/token-default pod/token-off --timeout=120s
```

Read the address of the `probe` Service in `starfleet`, then call it from `token-off`, which is in another namespace:

```sh
PROBE_IP=$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')
echo $PROBE_IP
kubectl -n network-demo exec token-off -- wget -q -T 3 -O- http://$PROBE_IP/
```

The request succeeds and returns one line of text that starts with `version=v1`. No policy exists, so the traffic crosses the namespace. Now block everything. Save this as `networkpolicy-default-deny.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: network-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Apply it:

```sh
kubectl apply -f networkpolicy-default-deny.yaml
```

Then check the result by repeating the request:

```sh
kubectl -n network-demo exec token-off -- wget -q -T 3 -O- http://$PROBE_IP/
```

After three seconds the command fails with `wget: download timed out`. The Calico plugin on the node dropped the packets. The failure is a timeout, not a refused connection, because a dropped packet gets no answer. A timeout where a refusal would normally come is a good sign of a network policy.

## Allow one path through the deny

Now allow only the `probe` Pods of `starfleet`, on the port they listen on. Save this as `networkpolicy-allow-probe.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-probe
  namespace: network-demo
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: starfleet
      podSelector:
        matchLabels:
          app: probe
    ports:
    - protocol: TCP
      port: 8080
```

Apply it:

```sh
kubectl apply -f networkpolicy-allow-probe.yaml
```

Then check the result by repeating the request:

```sh
kubectl -n network-demo exec token-off -- wget -q -T 3 -O- http://$PROBE_IP/
```

The request succeeds again and returns the `version=v1` line. The Service port is 80 and the rule names port 8080, and it still works, because the plugin matches the Pod port after the Service address is translated. The `namespaceSelector` and `podSelector` sit in the same list item, so both must match; as two list items they would allow either one.

The deny policy also blocks DNS, because DNS queries are egress traffic to the `kube-dns` Pods in `kube-system`. The test above used an IP address on purpose. A real default-deny setup needs an extra egress rule for port 53 over UDP and TCP.

## Remove the ServiceAccount token

Kubernetes mounts a ServiceAccount token into every Pod, at `/var/run/secrets/kubernetes.io/serviceaccount`. The token identifies the Pod to the API server. Most applications never call the API, so the token is only a credential for an attacker. List the directory in both Pods:

```sh
kubectl -n network-demo exec token-default -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n network-demo exec token-off -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

The first command lists three files: `ca.crt`, `namespace` and `token`. The second command fails with `No such file or directory`, because `automountServiceAccountToken: false` in the Pod spec disabled the mount. You can set the same field on a ServiceAccount, and then the Pods that use it get no token unless the Pod overrides it. The setting reduces what a compromised Pod can do through the API. It does not remove the network path to the API server; a NetworkPolicy does that.

Namespace isolation now has four layers: RBAC for people, Pod Security for Pod settings, quota for capacity, and network policy and token removal for a compromised Pod. All of them share one kernel per node.

## Common pitfalls

> [!WARNING]
> - **Assuming a NetworkPolicy works on any cluster.** Without a CNI plugin that enforces it, the object has no effect.
> - **Using the Service port in an egress rule.** The plugin checks the Pod port. A rule for port 80 does not match a Pod that listens on 8080.
> - **Writing `namespaceSelector` and `podSelector` as two list items.** That allows traffic that matches either one. Put them in the same item to require both.
> - **Forgetting DNS after a default-deny egress policy.** Name lookups fail even when the target is allowed.
> - **Forgetting the token on the ServiceAccount.** Set `automountServiceAccountToken: false` on the Pod or the ServiceAccount, and check with `ls`.
