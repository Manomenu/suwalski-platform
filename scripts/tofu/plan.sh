#!/usr/bin/env bash
# Pokaż, co tofu zamierza zrobić. Niczego nie zmienia — można puszczać do woli.
#   ./scripts/tofu/plan.sh                 maszyna i k3s
#   ./scripts/tofu/plan.sh platform        Argo CD
# Dalsze argumenty lecą do tofu, np. -target=... albo -out=plan.bin
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
    echo "brak $TF/.terraform — najpierw: cd terraform && tofu init" >&2
    exit 1
}

# Bez tego plan kończy się komunikatem o brakującej zmiennej, który nie mówi, skąd ją wziąć.
[ "$CEL" != "cluster" ] || [ -f "$TF/secrets.auto.tfvars" ] || {
    echo "brak $TF/secrets.auto.tfvars" >&2
    echo "  cp terraform/secrets.auto.tfvars.example terraform/secrets.auto.tfvars" >&2
    echo "  i uzupełnij token API oraz klucz SSH" >&2
    exit 1
}

cd "$TF"
tofu plan "$@"
