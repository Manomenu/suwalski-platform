#!/usr/bin/env bash
# Pokaż węzły klastra i ich obciążenie.
#
# Działa niezależnie od tego, czy masz ustawione KUBECONFIG — jeśli nie masz, bierze
# plik z repo. Dzięki temu da się zajrzeć do klastra ze świeżego terminala, bez
# wcześniejszego `source setup.sh`.
#
# Argumenty lecą do `kubectl get nodes`, np.: ./list-nodes.sh -o yaml
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v kubectl >/dev/null || {
    echo "brak kubectl — jest w ~/.dotfiles/fedora/nix/home.nix" >&2
    exit 1
}

# Zmienna z powłoki ma pierwszeństwo: jeśli świadomie wskazałeś inny klaster, skrypt
# nie ma prawa cię z niego przełączać.
if [ -z "${KUBECONFIG:-}" ]; then
    [ -f "$ROOT/kubeconfig" ] || {
        echo "brak $ROOT/kubeconfig i pustego KUBECONFIG" >&2
        echo "  $ROOT/scripts/kubeconfig.sh" >&2
        exit 1
    }
    export KUBECONFIG="$ROOT/kubeconfig"
fi

echo "==> węzły"
kubectl get nodes -o wide "$@"

# metrics-server k3s instaluje sam, ale po starcie potrzebuje chwili na pierwsze próbki.
# Brak danych nie jest błędem — dlatego osobno i bez przerywania skryptu.
echo
echo "==> obciążenie"
if kubectl top nodes 2>/dev/null; then
    :
else
    echo "    (metrics-server jeszcze nie ma próbek — spróbuj za minutę)"
fi
