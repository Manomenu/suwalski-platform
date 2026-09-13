#!/usr/bin/env bash
# Wspólna implementacja dla nakładek w scripts/cluster/ i scripts/platform/.
# Nie uruchamiaj wprost — od tego są tamte. Katalog .internal jest ukryty celowo:
# nic tu nie jest przeznaczone do wołania z ręki.
#
#   tofu.sh <validate|plan|apply> <cluster|platform> [argumenty do tofu]
set -euo pipefail

AKCJA="${1:?brak akcji}"; shift
CEL="${1:?brak celu}"; shift

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF="$ROOT/terraform/$CEL"

command -v tofu >/dev/null || {
    echo "brak tofu — jest w ~/.dotfiles/fedora/nix/home.nix, uruchom home-manager switch" >&2
    exit 1
}
[ -d "$TF" ] || { echo "nie ma takiej konfiguracji: $TF" >&2; exit 1; }

# validate i tak potrzebuje schematu providera, a ten pojawia się dopiero po init.
[ -d "$TF/.terraform" ] || {
    echo "brak $TF/.terraform — najpierw: (cd terraform/$CEL && tofu init)" >&2
    exit 1
}

# Sekrety są tylko w cluster/; platform bierze wszystko z kubeconfiga.
if [ "$CEL" = "cluster" ] && [ "$AKCJA" != "validate" ] && [ ! -f "$TF/secrets.auto.tfvars" ]; then
    echo "brak $TF/secrets.auto.tfvars" >&2
    echo "  cp terraform/cluster/secrets.auto.tfvars.example terraform/cluster/secrets.auto.tfvars" >&2
    exit 1
fi

# Odczyt wyjścia, które może jeszcze nie istnieć w stanie. Sprawdzamy przez -json, nie
# -raw: przy pustym stanie `output -raw` wypisuje ostrzeżenie NA STDOUT i kończy zerem,
# więc `||` nigdy by nie zadziałało.
wyjscie() {
    (cd "$TF" && tofu output -json "$1" >/dev/null 2>&1) || { printf '%s' "${2:-?}"; return; }
    (cd "$TF" && tofu output -raw "$1" 2>/dev/null)
}

cd "$TF"

case "$AKCJA" in
validate)
    echo "==> fmt"
    zmienione="$(tofu fmt -recursive)"
    [ -n "$zmienione" ] && printf '%s\n' "$zmienione" | sed 's/^/    przeformatowano: /' || echo "    bez zmian"
    echo "==> validate"
    tofu validate
    ;;

plan)
    tofu plan "$@"
    ;;

apply)
    # Provider Proxmoksa wgrywa cloud-init i importuje dysk przez SSH, nie przez API.
    # Pusty agent kończy się błędem w połowie, gdy maszyna już powstaje.
    if [ "$CEL" = "cluster" ] && ! ssh-add -l >/dev/null 2>&1; then
        echo "agent SSH nie ma żadnego klucza — provider nie wgra pliku cloud-init" >&2
        echo "  uruchom: ssh pve true" >&2
        exit 1
    fi

    tofu apply "$@"

    echo
    echo "== Dalej =="
    case "$CEL" in
    cluster)
        cat <<MSG
  k3s instaluje się jeszcze chwilę po tym, jak tofu skończy — cloud-init robi
  swoje w tle, zwykle dwie–trzy minuty.

  gotowość:   ssh $(wyjscie vm_user maniumek)@$(wyjscie vm_ip) 'ls /var/lib/cloud/k3s-ready'
  kubectl:    source $ROOT/scripts/cluster/kubectl-setup.sh
  podgląd:    k9s
MSG
        ;;
    platform)
        cat <<MSG
  Argo CD potrzebuje chwili, zanim wszystkie pody wstaną.

  podgląd:    k9s  ->  :po  ·  :ing  ·  :applications
  hasło:      $ROOT/scripts/platform/argocd-password.sh
  adres:      $(wyjscie argocd_url "(po apply)")
MSG
        ;;
    esac
    ;;
*)
    echo "nieznana akcja: $AKCJA" >&2; exit 2 ;;
esac
