#!/usr/bin/env bash
# Runs the commands the playground guide teaches and fails when one of them
# does not give the expected result.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-010-02" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

kubectl get namespaces starfleet outpost hardened -L pod-security.kubernetes.io/enforce
kubectl -n hardened get deployment scanner
failed_create=""
for attempt in $(seq 1 30); do
  failed_create="$(kubectl -n hardened get events --field-selector reason=FailedCreate -o custom-columns=MESSAGE:.message --no-headers | head -1)"
  [[ -n "$failed_create" ]] && break
  sleep 2
done
printf '%s\n' "$failed_create"
grep -q 'violates PodSecurity "restricted:v1.35"' <<<"$failed_create"

user="$(kubectl -n starfleet exec shuttle -- id)"
printf '%s\n' "$user"
grep -q '^uid=0(root)' <<<"$user"
status="$(kubectl -n starfleet exec shuttle -- grep -E 'CapEff|NoNewPrivs|Seccomp:' /proc/1/status)"
printf '%s\n' "$status"
grep -q 'CapEff:[[:space:]]*00000000a80425fb' <<<"$status"
grep -q 'NoNewPrivs:[[:space:]]*0' <<<"$status"
