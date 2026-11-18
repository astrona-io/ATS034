---
exam_objectives:
- Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
---
# Register The gVisor Handler In containerd Solution

Open a shell on the lab VM (virtual machine) and confirm that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-034-lab-030-02-01
kubectl config current-context
```

The output is `kubernetes-admin@astro-ats-034-lab-030-02-01`. Run every command below in this shell.

A runtime handler is a named entry in the containerd configuration. The kubelet sends the handler name from the RuntimeClass to containerd when it asks for a Pod sandbox, and containerd uses the entry to choose the shim, the small process that starts the low-level runtime. gVisor is a sandbox that runs its own kernel in user space for each Pod. Its shim is `containerd-shim-runsc-v1`.

## Find the failing component

Start with the Pod and its events:

```sh
kubectl -n tenant-b-034-030-02-01 get pod scout
kubectl -n tenant-b-034-030-02-01 get events --field-selector involvedObject.name=scout
```

The Pod is `0/1 ContainerCreating`. The events show `Scheduled`, so the scheduler did its job, and then repeated `FailedCreatePodSandBox` events from the kubelet. The message ends like this (the sandbox ID is shortened):

```text
Failed to create pod sandbox: rpc error: code = Unknown desc = unable to get OCI runtime for sandbox "2616d284...": no runtime for "runsc" is configured
```

The kubelet reports the error, but containerd produced it: containerd has no handler named `runsc`. The API server accepted the Pod because the RuntimeClass `gvisor` exists, and it does not check the nodes. Confirm the handlers that containerd has loaded:

```sh
sudo crictl info | jq '.config.containerd.runtimes | keys'
```

```text
[
  "runc"
]
```

The gVisor binaries are installed, so only the configuration is missing:

```sh
ls /usr/local/bin/runsc /usr/local/bin/containerd-shim-runsc-v1
```

## Register the handler

Look at the existing `runc` table to see the table path that this containerd version uses:

```sh
sudo grep -n -A1 'containerd.runtimes.runc\]' /etc/containerd/config.toml
```

```text
85:        [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
86-          runtime_type = 'io.containerd.runc.v2'
```

The file starts with `version = 3`, the format of containerd 2.x, where the CRI runtime settings live under `plugins.'io.containerd.cri.v1.runtime'`. Open the file with `sudo vi /etc/containerd/config.toml` and add this table at the end of the file:

```toml
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
```

The last part of the table name, `runsc`, is the handler name that the RuntimeClass uses. `io.containerd.runsc.v1` tells containerd to start `containerd-shim-runsc-v1`. Leave the `runc` table as it is.

## Restart containerd

containerd reads its configuration only when it starts. Restart it and check the loaded handlers:

```sh
sudo systemctl restart containerd
sudo crictl info | jq '.config.containerd.runtimes | keys'
```

```text
[
  "runc",
  "runsc"
]
```

Running containers keep running during the restart, because each one has its own shim process. If `crictl` reports that it cannot connect, wait a few seconds and run it again.

## Prove that scout runs under gVisor

You do not need to change the Pod. The kubelet keeps retrying the sandbox, and the next attempt succeeds. Wait for it:

```sh
kubectl -n tenant-b-034-030-02-01 wait --for=condition=Ready pod/scout --timeout=180s
kubectl -n tenant-b-034-030-02-01 exec scout -- dmesg
```

The kernel log starts with `Starting gVisor...` and ends with `Ready!`. That log comes from the gVisor kernel, not from the kernel of the node. Now ask containerd which handler created each sandbox:

```sh
sudo crictl pods --namespace tenant-b-034-030-02-01 --name scout
sudo crictl pods --namespace starfleet-034-030-02-01 --name shuttle
```

The `RUNTIME` column shows `runsc` for `scout` and `(default)` for `shuttle`. `shuttle` has no `runtimeClassName`, so containerd still runs it with `runc`.

## Common pitfalls

> [!WARNING]
> - Editing the file without a restart changes nothing. containerd keeps the old handlers until it starts again.
> - A wrong table path, such as the containerd 1.x path `plugins."io.containerd.grpc.v1.cri"` in a `version = 3` file, does not add the handler. containerd still starts, lists only `runc` and logs `Ignoring unknown key in TOML for plugin` for `plugin=io.containerd.grpc.v1.cri`. Compare with the `runc` table in the same file.
> - The table name must equal the `handler` field of the RuntimeClass. A table named `gvisor` gives the error `no runtime for "runsc" is configured` again.
> - Deleting `scout` is not needed. The kubelet retries the sandbox until it succeeds.
