# Cilium WireGuard And IPsec Encryption Playground

This ungraded playground is a kind cluster (Kubernetes 1.35, one control-plane node and one worker node) with Cilium 1.20.4 as its network plugin and transparent encryption turned off. The `probe` pod (BusyBox `httpd` on port 8080) runs on the worker node, the `shuttle` client pod runs on the control-plane node, and the `node-tools` DaemonSet runs `nicolaka/netshoot:v0.14` with host networking on each node for packet captures.

Cilium mounts the BPF filesystem on each node, so the playground needs Docker or rootful Podman. With rootless Podman the Cilium agent fails with `mount: /sys/fs/bpf: permission denied`. To switch Podman: `podman machine stop; podman machine set --rootful; podman machine start`.

`testing/smoke.sh` runs the steps the module pages teach: it checks that encryption is off, enables WireGuard, switches to IPsec with a key Secret and rotates the key to SPI 4. It never prints the key. Run it with `scripts/ci/test-playground.sh sections/section-040/module-03/playground`.
