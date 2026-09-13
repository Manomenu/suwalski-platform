#!/usr/bin/env bash
# Postaw albo zaktualizuj infrastrukturę. Pokazuje plan i pyta o zgodę.
#
# Domyślnie pyta o zgodę — to zabezpieczenie przed pomyłką, nie formalność.
# --yes-man pomija pytanie (przekłada się na -auto-approve). Nazwa jest celowo
# niewygodna: ma być widać w historii powłoki, że ktoś świadomie wyłączył hamulec.
set -euo pipefail

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --yes-man) ARGS+=(-auto-approve) ;;
        *) ARGS+=("$arg") ;;
    esac
done
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

[ -f "$TF/secrets.auto.tfvars" ] || {
    echo "brak $TF/secrets.auto.tfvars" >&2
    echo "  cp terraform/secrets.auto.tfvars.example terraform/secrets.auto.tfvars" >&2
    echo "  i uzupełnij token API oraz klucz SSH" >&2
    exit 1
}

# Provider wgrywa plik cloud-init i importuje dysk przez SSH, nie przez API — a klucz
# bierze z agenta. Pusty agent kończy się błędem w połowie apply, gdy maszyna już powstaje.
if ! ssh-add -l >/dev/null 2>&1; then
    echo "agent SSH nie ma żadnego klucza — provider nie wgra pliku cloud-init" >&2
    echo "  uruchom: ssh pve true    (wpis w ~/.ssh/config sam doda klucz do agenta)" >&2
    exit 1
fi

cd "$TF"
tofu apply ${ARGS[@]+"${ARGS[@]}"}

echo
echo "== Dalej =="
echo "k3s instaluje się jeszcze przez chwilę po tym, jak tofu skończy — cloud-init"
echo "robi swoje w tle, zwykle dwie–trzy minuty."
echo
tofu output -raw ssh 2>/dev/null | sed 's/^/  /' || true
echo "  $(tofu output -raw fetch_kubeconfig 2>/dev/null)"
echo
echo "  gotowość:  ssh $(tofu output -raw vm_ip 2>/dev/null | sed 's/^/maniumek@/') 'ls /var/lib/cloud/k3s-ready'"
