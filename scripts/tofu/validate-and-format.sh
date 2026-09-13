#!/usr/bin/env bash
# Sformatuj pliki i sprawdź je, nie łącząc się z Proxmoksem.
# Puszczaj przed każdym commitem — obie rzeczy są lokalne i trwają sekundę.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF="$ROOT/terraform"

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
