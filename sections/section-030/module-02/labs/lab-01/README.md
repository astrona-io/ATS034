# Register The gVisor Handler In containerd

Find why a Pod with `runtimeClassName: gvisor` stays in `ContainerCreating`, register the `runsc` handler in containerd, restart containerd and prove that the Pod runs under gVisor.

The lab runs one QEMU VM from the `24.04-cks` image of [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image). The image ships gVisor (`runsc`, `containerd-shim-runsc-v1`) and registers the `runsc` handler in containerd. `bootstrap/setup.sh` removes the `runsc` table from `/etc/containerd/config.toml`, restarts containerd, checks that the handler is gone and then creates the RuntimeClass and the Pods.

The graders read `crictl info` and `/etc/containerd/config.toml` on the node, the `scout` Pod, `dmesg` inside it and `crictl pods` for `scout` and `shuttle`. The `vm/` folder is generated: change the lab files and run `python3 scripts/ci/vm-lab.py sections/section-030/module-02/labs/lab-01`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
