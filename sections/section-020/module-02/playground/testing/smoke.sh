#!/usr/bin/env bash
# Runs the commands of the guided practice and checks their results, then
# removes what it created. Exits non-zero when a result is not as taught.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-034-playground-020-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace=starfleet
work_directory="$(mktemp -d)"
cleanup() {
  kubectl -n "$namespace" delete pod login-reader --ignore-not-found --wait=false >/dev/null
  kubectl -n "$namespace" delete secret probe-login --ignore-not-found >/dev/null
  rm -rf "$work_directory"
}
trap cleanup EXIT

kubectl -n "$namespace" wait --for=condition=Available deployment/probe --timeout=180s
kubectl -n "$namespace" get secret practice-token >/dev/null

cat > "$work_directory/secret-probe-login.yaml" <<'MANIFEST'
apiVersion: v1
kind: Secret
metadata:
  name: probe-login
  namespace: starfleet
type: kubernetes.io/basic-auth
immutable: true
stringData:
  username: scout
  password: disposable-login
---
apiVersion: v1
kind: Pod
metadata:
  name: login-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    volumeMounts:
    - name: login
      mountPath: /login
      readOnly: true
  volumes:
  - name: login
    secret:
      secretName: probe-login
      defaultMode: 0400
MANIFEST
kubectl apply -f "$work_directory/secret-probe-login.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/login-reader --timeout=180s
kubectl -n "$namespace" exec login-reader -- sh -c 'test "$(cat /login/username)" = scout && test "$(cat /login/password)" = disposable-login'

if patch_output="$(kubectl -n "$namespace" patch secret probe-login --type merge -p '{"stringData":{"password":"changed"}}' 2>&1)"; then
  printf 'The patch of an immutable Secret was accepted\n' >&2
  exit 1
fi
grep -q immutable <<<"$patch_output" || { printf 'Unexpected patch error: %s\n' "$patch_output" >&2; exit 1; }

test "$(kubectl auth can-i list secrets -n "$namespace" --as "system:serviceaccount:$namespace:default")" = no
echo "smoke test passed"
