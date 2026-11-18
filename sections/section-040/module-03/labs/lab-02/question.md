---
draft: true
---
# Encrypt And Observe Cross-Node Traffic

Solve this question on: `terminal`

This independent Ubuntu VM runs two kind nodes with real Cilium. The `client` and `server` Pods in `encryption-training` are on different nodes. HTTP works, but Cilium encryption is initially disabled.

Allow about 15 minutes for the tasks. VM and cluster startup add several minutes.

## Tasks

1. Upgrade the installed Cilium release with the cached chart `/etc/training/cilium-1.20.4.tgz`, preserving its values and enabling WireGuard encryption. Restart the agents and wait for rollout completion.
2. Verify both node kernels have WireGuard peers, then make fresh cross-node HTTP requests. Capture the request inside `cilium_wg0` and encrypted transport on `eth0`; show that the request payload is absent from the outer capture.

## Constraints

Use `/etc/training/kubeconfig`. Keep the workloads on their original separate nodes, preserve the application and do not replace Cilium. Do not enable node-to-node encryption or change the API server. This task covers Pod-to-Pod traffic across nodes, not same-node or external traffic.

## How the answer is checked

The grader reads actual WireGuard peers in both node network namespaces. It generates unique HTTP requests, captures both interfaces, confirms the response and inner request payload, and requires WireGuard packets without that plaintext payload on the outer interface.
