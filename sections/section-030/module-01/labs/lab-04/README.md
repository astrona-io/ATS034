# Run A Pod Under gVisor With A RuntimeClass

Create a RuntimeClass for the `runsc` handler, run a Pod with it and prove from inside the Pod and from containerd that gVisor runs it.

The lab runs one QEMU VM from the `24.04-cks` image of [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image). The image ships gVisor (`runsc`, `containerd-shim-runsc-v1`) and registers the `runsc` runtime handler in containerd. `vm/install.sh` builds the one-node kubeadm cluster, copies the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh`, which stops when containerd does not report the handler.

The graders read the RuntimeClass, the Pod, `dmesg` and `uname -r` inside the Pod, `uname -r` on the node and `crictl pods` on the node. The `vm/` folder is generated: change the lab files and run `python3 scripts/ci/vm-lab.py sections/section-030/module-01/labs/lab-04`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
