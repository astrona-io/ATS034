---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment To Meet Restricted

Repair a Deployment that Pod Security Admission blocks, so its Pod runs as a non-root user with a read-only root filesystem.

## Starting state

The namespace `hardened` enforces the Restricted profile at version v1.35. The `scanner` Deployment in it has one replica and no Ready Pod. Its container uses `busybox`, runs as the image default user and writes the file `/tmp/result` before it sleeps. The `starfleet` and `outpost` namespaces from the shared environment also exist and must not change.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-ats-034-lab-010-02-01" || exit 1
node_name="astro-ats-034-lab-010-02-01-control-plane"
worker_name="astro-ats-034-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Repair the `scanner` Deployment in `hardened`. Keep its name, replica count, selector, image and command. Change only the Pod template so that it has all of the following.

- Pod level: `runAsNonRoot: true`, `runAsUser: 1000` and a `seccompProfile` of type `RuntimeDefault`.
- Container `scanner`: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and all capabilities dropped.
- An `emptyDir` volume named `tmp`, mounted at `/tmp` in the container.

Do not change the labels of the `hardened` namespace. When you finish, the Deployment has one Ready Pod, the process runs as user ID 1000 with `no_new_privs` set, `/tmp/result` contains `scan`, and a write to `/` fails.

## Verify The Result

The grader checks the Deployment fields and runs bounded commands in the Pod. Wait for the rollout before you submit, and read the `FailedCreate` event if the Deployment does not become Ready. Preserve the namespace labels and unrelated components.
