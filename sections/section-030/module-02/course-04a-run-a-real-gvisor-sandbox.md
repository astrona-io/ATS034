---
draft: true
---
# Start And Verify A Real gVisor Sandbox

A RuntimeClass chooses a container-runtime handler; its name does not add isolation. A handler mapped to `runc` still uses ordinary Linux containers. gVisor's `runsc` executes workloads through an application kernel that handles many system calls outside the host kernel.

This independent exercise uses Docker inside an Ubuntu QEMU VM to make the runtime boundary visible. It complements Kubernetes handler selection with a real gVisor process. Connect with `astrona ssh ats-034-lab-030-02-02`. The bootstrap installs a pinned release, verifies its archive checksum and preserves its supporting binaries together under `/usr/local/bin`.

<!-- astrona:playground:renew -->

Inspect the available runtime and register it:

```sh
sudo /usr/local/bin/runsc --version
sudo /usr/local/bin/runsc install --runtime=runsc -- --platform=systrap
sudo systemctl restart docker
sudo docker info --format '{{json .Runtimes}}'
```

`systrap` is gVisor's system-call interception platform. It works inside a VM without nesting another hardware virtual machine. Restarting Docker loads the runtime registration. This command affects only Docker inside the disposable VM.

Run a fresh container with explicit runtime selection:

```sh
sudo docker run --rm --runtime=runsc --network=none busybox:1.37.0 dmesg
```

The output should identify gVisor. Kernel-log text is useful diagnostic evidence in a trusted lab, but an untrusted workload can imitate output. Combine it with runtime configuration, the installed executable and the container's runtime identity.

Start a small HTTP workload:

```sh
sudo docker run -d --name scout --runtime=runsc \
  -p 127.0.0.1:8080:8080 -v /srv/scout:/www:ro \
  busybox:1.37.0 httpd -f -p 8080 -h /www
sudo docker inspect scout --format '{{.HostConfig.Runtime}}'
curl --max-time 5 http://127.0.0.1:8080/
```

The mount is read-only and the published port binds to VM loopback. The runtime boundary must preserve the required application behavior. gVisor has compatibility and performance tradeoffs, so a workload starting successfully does not establish that every application feature will work.

## Common pitfalls

> [!WARNING]
> Registering a runtime does not move existing containers into it. Recreate a container with explicit `--runtime=runsc`. Keep all files from the pinned gVisor archive together; recent releases include supporting binaries as well as runsc.
