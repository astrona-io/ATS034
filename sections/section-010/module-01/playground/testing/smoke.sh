#!/usr/bin/env bash
# Runs the commands the playground guide teaches and fails when one of them
# does not give the expected result.
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-034-playground-010-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
work_directory="$(mktemp -d)"
trap 'kubectl delete namespace restricted-demo --ignore-not-found --wait=false >/dev/null; rm -rf "$work_directory"' EXIT
# The guide saves the file in the current directory, so the error text names it the same way.
cd "$work_directory"

kubectl get namespaces starfleet outpost --show-labels
kubectl -n starfleet get pods

inventory="$(kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted 2>&1)"
printf '%s\n' "$inventory"
grep -q 'violate the new PodSecurity enforce level "restricted:latest"' <<<"$inventory"

kubectl create namespace restricted-demo
kubectl label namespace restricted-demo pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
cat > pod-privileged.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged-check
  namespace: restricted-demo
spec:
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
EOF
if rejected="$(kubectl apply --dry-run=server -f pod-privileged.yaml 2>&1)"; then
  printf 'A privileged Pod was admitted in a Restricted namespace\n' >&2
  exit 1
fi
printf '%s\n' "$rejected"
grep -q 'violates PodSecurity "restricted:v1.35"' <<<"$rejected"
