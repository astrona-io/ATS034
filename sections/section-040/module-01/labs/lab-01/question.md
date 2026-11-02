---
draft: true
exam_objectives:
- Implement Pod-to-Pod encryption (Cilium, Istio)
---
# Require Mutual TLS Between Workloads

Require mesh-authenticated traffic while keeping the injected client able to reach the application.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-040-01-01" || exit 1
node_name="astro-ats-034-lab-040-01-01-control-plane"
worker_name="astro-ats-034-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Apply namespace-strict PeerAuthentication with STRICT mutual TLS to starfleet. Keep Istio 1.30.5 running and the application and shuttle Pods injected and Ready. Shuttle with its proxy must receive version one, while the unmeshed outpost drifter must fail its plaintext request with a connection-reset response. This verifies one service-mesh boundary, not host traffic or encryption for every possible path.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
