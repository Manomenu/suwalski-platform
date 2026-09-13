#!/usr/bin/env bash
# Pokaż, co tofu zamierza zrobić. Niczego nie zmienia — można puszczać do woli.
# Argumenty lecą dalej, więc działa np. ./scripts/tofu/plan.sh -target=... albo -out=plan.bin
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF="$ROOT/terraform"

command -v tofu >/dev/null || {
    echo "brak tofu — jest w ~/.dotfiles/fedora/nix/home.nix, uruchom home-manager switch" >&2
    exit 1
}

[ -d "$TF/.terraform" ] || {
    echo "brak $TF/.terraform — najpierw: cd terraform && tofu init" >&2
    exit 1
}

# Bez tego plan kończy się komunikatem o brakującej zmiennej, który nie mówi, skąd ją wziąć.
[ -f "$TF/secrets.auto.tfvars" ] || {
    echo "brak $TF/secrets.auto.tfvars" >&2
    echo "  cp terraform/secrets.auto.tfvars.example terraform/secrets.auto.tfvars" >&2
    echo "  i uzupełnij token API oraz klucz SSH" >&2
    exit 1
}

cd "$TF"
tofu plan "$@"
