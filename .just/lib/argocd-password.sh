#!/usr/bin/env bash
# Hasło początkowe użytkownika admin w Argo CD.
#
# Argo generuje je przy pierwszej instalacji i zapisuje w sekrecie. Po zmianie hasła
# w interfejsie ten sekret można skasować — wtedy ten skrypt przestanie działać i to
# jest w porządku.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v kubectl >/dev/null || { echo "brak kubectl" >&2; exit 1; }
# Zawsze własny plik, nie KUBECONFIG z powłoki: ten złożony z wielu klastrów celuje w ten,
# który akurat jest wybrany — a to może być GKE z suwalski-gcloud-platform.
[ -f "$ROOT/kubeconfig" ] || { echo "brak $ROOT/kubeconfig — just cluster kubeconfig" >&2; exit 1; }
export KUBECONFIG="$ROOT/kubeconfig"

NS="${ARGOCD_NAMESPACE:-argocd}"

if ! kubectl -n "$NS" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
    echo "brak sekretu argocd-initial-admin-secret w przestrzeni $NS" >&2
    echo "  albo Argo jeszcze nie wstało, albo hasło zostało już zmienione" >&2
    exit 1
fi

echo "użytkownik: admin"
printf 'hasło:      '
kubectl -n "$NS" get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d
echo
