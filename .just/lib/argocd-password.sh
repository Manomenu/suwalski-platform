#!/usr/bin/env bash
# Initial password of the admin user in Argo CD.
#
# Argo generates it on the first install and stores it in a secret. After changing the
# password in the UI that secret can be deleted — then this script stops working, and that
# is fine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v kubectl >/dev/null || { echo "kubectl not found" >&2; exit 1; }
# Always our own file, not KUBECONFIG from the shell: one merged from many clusters targets
# whichever happens to be selected — and that may be GKE from suwalski-gcloud-platform.
[ -f "$ROOT/kubeconfig" ] || { echo "missing $ROOT/kubeconfig — just cluster kubeconfig" >&2; exit 1; }
export KUBECONFIG="$ROOT/kubeconfig"

NS="${ARGOCD_NAMESPACE:-argocd}"

if ! kubectl -n "$NS" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
    echo "no argocd-initial-admin-secret secret in namespace $NS" >&2
    echo "  either Argo is not up yet, or the password has already been changed" >&2
    exit 1
fi

echo "user:     admin"
printf 'password: '
kubectl -n "$NS" get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d
echo
