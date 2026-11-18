#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-lab-010-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# Inventory: a server-side dry run of the enforce label lists the running Pods it would reject.
for namespace in bridge-034-010-03-01 starfleet-034-010-03-01 outpost-034-010-03-01; do
  kubectl label --dry-run=server --overwrite namespace "$namespace" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
done
kubectl label --overwrite namespace bridge-034-010-03-01 \
  pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
for namespace in starfleet-034-010-03-01 outpost-034-010-03-01; do
  kubectl label --overwrite namespace "$namespace" \
    pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/warn-version=v1.35
done
