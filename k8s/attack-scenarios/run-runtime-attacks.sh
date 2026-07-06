#!/usr/bin/env bash
# Drives the runtime attack scenarios that the custom Falco rules are built to
# catch. Deploys the vulnerable pod, then executes each technique inside it and
# tails Falco so you can watch the alerts fire in real time.
#
# Usage: bash run-runtime-attacks.sh
# Requires: kubectl context pointing at the lab cluster, Falco installed.
set -euo pipefail

POD=vulnerable-app
NS=default
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/3] Deploying vulnerable pod"
kubectl apply -f "$here/../vulnerable-pods/privileged-pod.yaml"
kubectl wait --for=condition=ready "pod/$POD" -n "$NS" --timeout=90s

echo "[2/3] Streaming Falco alerts (background) — give it a few seconds"
falco_pod="$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o name | head -1)"
kubectl logs -f -n falco "$falco_pod" 2>/dev/null | grep --line-buffered -iE 'shell|sensitive|escape|unauthorized|drop' &
tail_pid=$!
sleep 3

run() { echo; echo ">>> $1"; kubectl exec "$POD" -n "$NS" -- sh -c "$2" 2>/dev/null || true; sleep 2; }

echo "[3/3] Executing attack techniques"
run "T1059 Terminal shell in container"        "bash -c 'echo shell-spawned'"
run "T1552 Read /etc/shadow (credential access)" "cat /etc/shadow || true"
run "T1552 Read /etc/passwd (credential access)" "cat /etc/passwd"
run "T1078 Read service account token"          "cat /run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || echo no-token"
run "T1611 Container escape via host mount"     "mount --bind /host/etc /mnt 2>/dev/null || ls /host/etc >/dev/null"
run "T1105 Drop and execute new binary"         "cp /bin/echo /tmp/dropped && /tmp/dropped executed"

sleep 3
kill "$tail_pid" 2>/dev/null || true
echo
echo "Done. Review full alert history:"
echo "  kubectl logs -n falco $falco_pod | grep -iE 'Warning|Critical|Notice'"
