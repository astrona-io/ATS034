# gVisor Sandbox Playground

Author README for the ungraded playground of the sandboxed runtimes module. The guide is in `docs/overview.md`.

The playground runs one QEMU VM from the `24.04-cks` image of [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image). The image ships a held kubeadm v1.35 node, containerd 2.2.1 (configuration `version = 3`), gVisor `runsc` and `containerd-shim-runsc-v1` in `/usr/local/bin`, the `runsc` handler table in `/etc/containerd/config.toml`, and `/usr/local/sbin/astrona-kubeadm-init`.

`bootstrap/setup.sh` runs inside the VM as the `astrona` user. It creates the single-node cluster `astro-ats-034-playground-030-02` (control plane without taint), gives the `astrona` and `student` users a kubeconfig, checks that containerd has loaded the `runsc` handler and creates the namespace `tenant-b`. The start object is inlined, because astrona copies no other files into the VM. The learner logs in as `student` with `astrona ssh astro-ats-034-playground-030-02`.

`testing/smoke.sh` takes the YAML blocks straight from the module pages and runs the page commands inside the VM (handler tables and `crictl`, the gVisor Pod and its kernel, the missing class and missing handler, RuntimeClass overhead and node selector, the `require-sandbox` ValidatingAdmissionPolicy). It fails when a result differs from what the page says. Run it with `scripts/ci/test-playground.sh sections/section-030/module-02/playground`; the script copies the pages into the VM over SSH and runs the smoke test there as `student`. The playground has no grading or solution files. The commands and outputs in the module parts were run on this playground on the arm64 image.
