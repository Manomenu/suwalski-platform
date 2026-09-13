#!/usr/bin/env bash
# Sformatuj pliki i sprawdź je, nie łącząc się z niczym.
#
#   ./scripts/tofu/validate-and-format.sh            cluster
#   ./scripts/tofu/validate-and-format.sh platform   platform
# Puszczaj przed każdym commitem — obie rzeczy są lokalne i trwają sekundę.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Która konfiguracja: cluster (maszyna i k3s) czy platform (Argo CD).
# Domyślnie cluster, bo od niego się zaczyna i on się zmienia rzadziej.
CEL="cluster"
case "${1:-}" in
    cluster|platform) CEL="$1"; shift ;;
esac
TF="$ROOT/terraform/$CEL"

command -v tofu >/dev/null || {
    echo "brak tofu — jest w ~/.dotfiles/fedora/nix/home.nix, uruchom home-manager switch" >&2
    exit 1
}

[ -d "$TF/.terraform" ] || {
    # validate potrzebuje schematu providera, a ten pojawia się dopiero po init.
    echo "brak $TF/.terraform — najpierw: cd terraform && tofu init" >&2
    exit 1
}

cd "$TF"

echo "==> fmt"
# -recursive obejmuje też templates/; bez tego katalog zostaje nietknięty.
# tofu fmt wypisuje nazwy plików, które zmienił — cisza znaczy, że było już dobrze.
changed="$(tofu fmt -recursive)"
if [ -n "$changed" ]; then
    echo "$changed" | sed 's/^/    przeformatowano: /'
else
    echo "    bez zmian"
fi

echo "==> validate"
tofu validate
