#!/usr/bin/env bash
# Co Argo CD ma w środku i czy wstało.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v kubectl >/dev/null || { echo "brak kubectl" >&2; exit 1; }
[ -n "${KUBECONFIG:-}" ] || export KUBECONFIG="$ROOT/kubeconfig"

NS="${ARGOCD_NAMESPACE:-argocd}"

# `get pods` na nieistniejącej przestrzeni NIE jest błędem — wypisuje „No resources found"
# i kończy zerem. Dlatego pytamy wprost o przestrzeń.
if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
    echo "brak przestrzeni $NS — Argo CD nie jest zainstalowane" >&2
    echo "  ./scripts/tofu/apply.sh platform" >&2
    exit 1
fi

echo "==> pody"
kubectl -n "$NS" get pods -o wide 2>/dev/null | sed 's/^/    /'

echo
echo "==> jak wejść"
kubectl -n "$NS" get ingress -o custom-columns='HOST:.spec.rules[*].host,KLASA:.spec.ingressClassName' --no-headers 2>/dev/null \
    | awk '{print "    http://"$1"   (ingress: "$2")"}'

echo
echo "==> aplikacje, którymi zarządza"
if kubectl -n "$NS" get applications.argoproj.io --no-headers 2>/dev/null | grep -q .; then
    kubectl -n "$NS" get applications.argoproj.io 2>/dev/null | sed 's/^/    /'
else
    echo "    (żadnych — dojdą w Fazie 5)"
fi
