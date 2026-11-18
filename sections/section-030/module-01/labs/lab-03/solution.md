---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Isolate A Tenant Namespace And Remove Its Token Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-030-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-030-01-03" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

A NetworkPolicy is a namespaced object that says which traffic may reach or leave the Pods it selects. The network plugin, here Calico, enforces it on each node. Without any NetworkPolicy, every Pod can open a connection to every other Pod in the cluster. Store the two target addresses first, because the policies will block DNS (Domain Name System) lookups later:

```sh
PROBE_IP=$(kubectl -n starfleet-034-030-01-03 get service probe -o jsonpath='{.spec.clusterIP}')
BEACON_IP=$(kubectl -n starfleet-034-030-01-03 get pod beacon -o jsonpath='{.status.podIP}')
kubectl -n tenant-a-034-030-01-03 exec worker -- wget -q -T 3 -O- http://$BEACON_IP:8080/
```

The request succeeds and prints `version=v1 app=beacon host=beacon`. The `worker` Pod reaches a Pod it has no reason to talk to.

## Deny all traffic, then allow one path

A policy with an empty `podSelector` selects every Pod in its namespace. When it lists both `Ingress` and `Egress` in `policyTypes` and has no rules, it allows nothing in either direction. A second policy then adds one allowed egress path. Policies only add allowed traffic, so the two together allow exactly that path. Save this as `networkpolicy-tenant-a.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: tenant-a-034-030-01-03
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-probe
  namespace: tenant-a-034-030-01-03
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: starfleet-034-030-01-03
      podSelector:
        matchLabels:
          app: probe
    ports:
    - protocol: TCP
      port: 8080
```

The `namespaceSelector` and the `podSelector` sit in the same list item, so a peer must match both: a Pod with `app: probe` in the `starfleet-034-030-01-03` namespace. The port is the container port `8080`, not the Service port `80`. Calico checks the policy after the Service address is translated to a Pod address. Apply it:

```sh
kubectl apply -f networkpolicy-tenant-a.yaml
```

Then check the result:

```sh
kubectl -n tenant-a-034-030-01-03 exec worker -- wget -q -T 3 -O- http://$PROBE_IP/
kubectl -n tenant-a-034-030-01-03 exec worker -- wget -q -T 3 -O- http://$BEACON_IP:8080/
```

The first request prints a line such as `version=v1 app=probe host=probe-7558d4bf9f-jjmn9` (the Pod name differs on your cluster). The second request prints `wget: download timed out` and `command terminated with exit code 1`. Calico drops the packets, so the client waits until its 3-second timeout ends instead of getting a quick refusal.

## Stop mounting the ServiceAccount token

A ServiceAccount is the identity a Pod uses when it talks to the API server. By default, the kubelet mounts a token for that ServiceAccount into every container at `/var/run/secrets/kubernetes.io/serviceaccount`. Today the directory holds `ca.crt`, `namespace` and `token`. The `worker` Pod never calls the API server, so the token is only something an attacker could steal.

The field `automountServiceAccountToken: false` on the ServiceAccount stops the mount for new Pods. The kubelet mounts volumes only when it starts a Pod, so the running `worker` keeps its token until you recreate it. Save this as `pod-worker.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: worker
  namespace: tenant-a-034-030-01-03
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: worker
  namespace: tenant-a-034-030-01-03
  labels:
    app: worker
spec:
  serviceAccountName: worker
  containers:
  - name: worker
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
```

A Pod spec cannot change its volumes after creation, so delete the old Pod first. Apply it:

```sh
kubectl -n tenant-a-034-030-01-03 delete pod worker
kubectl apply -f pod-worker.yaml
kubectl -n tenant-a-034-030-01-03 wait --for=condition=Ready pod/worker --timeout=120s
```

Then check the result:

```sh
kubectl -n tenant-a-034-030-01-03 exec worker -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

The command prints `ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory` and exits with code 1. The new Pod runs with the same ServiceAccount but has no token. The NetworkPolicies still apply to it, because they select Pods by namespace and labels, not by Pod name.

When you are done, remove the lab with `astrona destroy ats-034-lab-030-01-03`.

## Common pitfalls

> [!WARNING]
> A default-deny egress policy also blocks DNS, so a request to `http://probe.starfleet-034-030-01-03/` fails even when the path to the Pod is allowed. Test with IP addresses, or add an egress rule for DNS when the workload needs names.
>
> Writing `namespaceSelector` and `podSelector` as two list items (two dashes) allows every Pod in that namespace or every `app: probe` Pod anywhere. Keep them in one item.
>
> Setting the field on the ServiceAccount does not remove the token from a running Pod. Recreate the Pod and check the directory again.
