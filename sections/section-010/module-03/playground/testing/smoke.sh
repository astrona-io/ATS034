#!/usr/bin/env bash
# Runs the commands the playground guide teaches and fails when one of them
# does not give the expected result.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-010-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

kubectl get namespaces -L pod-security.kubernetes.io/enforce,pod-security.kubernetes.io/warn,pod-security.kubernetes.io/audit

for namespace in starfleet outpost; do
  inventory="$(kubectl label --dry-run=server --overwrite namespace "$namespace" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35 2>&1)"
  printf '%s\n' "$inventory"
  grep -q "existing pods in namespace \"$namespace\" violate the new PodSecurity enforce level \"restricted:v1.35\"" <<<"$inventory"
done

flags="$(kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep -E 'admission|enable' || true)"
printf '%s\n' "$flags"
if grep -q 'admission-control-config-file' <<<"$flags"; then
  printf 'The API server unexpectedly has an admission configuration file\n' >&2
  exit 1
fi

answer="$(kubectl auth can-i update namespaces --as=system:serviceaccount:starfleet:default 2>/dev/null || true)"
printf 'can-i update namespaces: %s\n' "$answer"
[[ "$answer" == no ]]
