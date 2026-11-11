---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Repair A Deployment To Meet Restricted

Solve this question on: `terminal`

The namespace `hardened-034-010-02-01` enforces the Restricted profile at version v1.35. The `scanner` Deployment in it has one replica and no Ready Pod. Its container uses `busybox`, runs as the image default user and writes the file `/tmp/result` before it sleeps. The `starfleet-034-010-02-01` and `outpost-034-010-02-01` namespaces from the shared environment also exist and must not change.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-034-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-034-lab-010-02-01" || exit 1
node_name="astro-ats-034-lab-010-02-01-control-plane"
worker_name="astro-ats-034-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find out why the `scanner` Deployment has no Pod. Read the `FailedCreate` event of its ReplicaSet.
2. In the Pod template, set `runAsNonRoot: true`, `runAsUser: 1000` and a `seccompProfile` of type `RuntimeDefault` at Pod level.
3. In the container `scanner`, set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and drop all capabilities.
4. Add an `emptyDir` volume named `tmp`, mount it at `/tmp` in the container, and wait until the Deployment has one Ready Pod.

## Constraints

- Keep the Deployment name, replica count, selector, image and command. Change only the Pod template.
- Do not change the labels of the `hardened-034-010-02-01` namespace.

## How the answer is checked

The grader runs four checks: the Pod-level security context, the container security context, the `tmp` volume and its mount, and a running Pod. The last one needs one Ready replica and runs bounded commands in it: the process runs as user ID 1000 with `no_new_privs` set, `/tmp/result` contains `scan`, and a write to `/` fails. Every check also confirms that the namespace labels, the name, replica count, selector and image are unchanged.

Hint: `kubectl explain deployment.spec.template.spec.securityContext` lists the Pod-level fields.
