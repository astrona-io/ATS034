---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Summary

A Pod Security label takes effect for every new Pod in a namespace at once, so a rollout starts with a look at the cluster. The command `kubectl get namespaces -L` with the three label keys shows which namespaces have labels. A server-side dry run of a label change, for one namespace or for all of them with `--all`, makes the API server check the existing Pods against the new profile and print a warning for each one that fails. A field listing with `custom-columns` finds where a single setting is used.

A staged change uses the three modes in order. First `warn` and `audit` are set to the target profile with their version labels. The warnings tell the people who deploy what to fix. After the workloads are corrected, a dry run of the `enforce` label must print no warning. Then `enforce` is set with a pinned version. Labels never remove running Pods, so a problem appears only when a Pod is created again.

Namespaces without labels follow the defaults in the admission configuration file that the API server reads at start, through the flag `--admission-control-config-file`. The built-in default is Privileged. The same file lists exemptions by user name, RuntimeClass and namespace. An exempt request skips every check, so the lists must stay short. The order of decision is the exemption, then the namespace label, then the default.

Workloads that need node access belong in a namespace that is labelled Privileged on purpose, with `warn` and `audit` set to a stricter profile so that each exception leaves a record. All other namespaces enforce Baseline or Restricted. A pinned `enforce-version` keeps the rules stable through a cluster upgrade, and `warn-version` set to `latest` previews the next rules. Permission to update namespaces lets a user remove the labels, so RBAC must limit it. The key facts to remember are these:

- Dry-run the label change before you apply it, and read every warning.
- Set `warn` and `audit` before `enforce`, and pin versions on all three.
- Exemptions exist only in the admission configuration file, not in labels.
- Create namespaces together with their labels, in one manifest.

<!-- astrona:playground:destroy -->
