---
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Rotate The Cilium IPsec Key

Allow about 15 minutes for the tasks.

This lab needs Docker or rootful Podman, because Cilium mounts the BPF filesystem on each node; to switch Podman, run `podman machine stop; podman machine set --rootful; podman machine start`.

Cilium encrypts the traffic between the nodes with IPsec, and the key has been in use since the cluster was built. Replace it with a new key without stopping the traffic between `shuttle` and `probe` in `starfleet-034-040-03-02`.

## Connect to the lab

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-03-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

## Starting state

Cilium 1.20.4 is the network plugin of the cluster, installed with Helm as the release `cilium` in `kube-system` with `encryption.enabled=true` and `encryption.type=ipsec`. IPsec (Internet Protocol Security) encrypts each IP packet between the nodes with a shared key. The agents read the key from the Secret `cilium-ipsec-keys` in `kube-system`, data key `keys`. It holds one line with four fields: the SPI (security parameter index, the number that names the key) `3+`, the algorithm `rfc4106(gcm(aes))`, a key of 40 hexadecimal characters and the length `128`.

The namespace `starfleet-034-040-03-02` runs the pod `probe` on the worker node, with a BusyBox HTTP server on port 8080 that answers `probe-reply`, and the Service `probe` on port 8080. The pod `shuttle` runs on the control-plane node and has BusyBox `wget` in its container `client`.

## Tasks

1. Replace the key in the Secret `cilium-ipsec-keys` with a new random key. Use a higher SPI than the current one and keep the same format.
2. Wait until the Cilium agents on both nodes use the new key, with no IPsec errors.
3. The `shuttle` pod must still get `probe-reply` from `http://probe.starfleet-034-040-03-02.svc.cluster.local:8080/`.
4. On `eth0` of the worker node, the traffic between `shuttle` and `probe` must be ESP (Encapsulating Security Payload, the encrypted IPsec packet format) with the new SPI only. No packet may still carry SPI 3, and the text `probe-reply` must never appear there in plain text.
5. Never print the key itself in your terminal.

The image `docker.io/nicolaka/netshoot:v0.14`, which contains `tcpdump`, is loaded on both nodes.

## Check your work

Show the key line without the key value, then ask each agent for its IPsec state:

```sh
kubectl -n kube-system get secret cilium-ipsec-keys -o jsonpath='{.data.keys}' | base64 -d | cut -d' ' -f1,2,4
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg encrypt status
```

Each agent must report `Encryption: IPsec` and `Errors: 0`. Then send one request across the nodes:

```sh
kubectl -n starfleet-034-040-03-02 exec shuttle -c client -- wget -q -T 3 -O- http://probe.starfleet-034-040-03-02.svc.cluster.local:8080/
```

The command must print `probe-reply`. Finally, capture ESP packets on the worker node with a debugging pod in the network namespace of the node, send the request again while the capture runs, and read the capture:

```sh
WORKER_NODE=$(kubectl -n starfleet-034-040-03-02 get pod probe -o jsonpath='{.spec.nodeName}')
kubectl -n starfleet-034-040-03-02 debug node/$WORKER_NODE --profile=sysadmin --image=docker.io/nicolaka/netshoot:v0.14 -- timeout 20 tcpdump -ni eth0 -c 10 esp
kubectl -n starfleet-034-040-03-02 logs <node-debugger-pod>
```

Every `ESP(spi=...)` line must show the new SPI.
