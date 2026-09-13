#!/usr/bin/env bash
# Przygotowanie świeżo sklonowanego repozytorium. Idempotentne — uruchamiaj ile chcesz.
#
# Jedno źródło prawdy dla sekretów: .secrets.env w korzeniu repo, poza gitem.
# Ten skrypt pyta o wartości i ROZPROWADZA je tam, gdzie są potrzebne:
#
#   .secrets.env  ──┬──>  terraform/cluster/secrets.auto.tfvars
#                   └──>  Secret w klastrze (dla aplikacji)
#
# Dzięki temu sekret dzielony między warstwami podaje się RAZ. Kopie w docelowych
# miejscach są generowane, nigdy edytowane ręcznie.
#
# ⚠ Przejściowe. Docelowo sekrety mają leżeć w gicie zaszyfrowane — patrz TODO.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZRODLO="$ROOT/.secrets.env"

# ── odczyt tego, co już mamy ──────────────────────────────────────────────────
declare -A OBECNE=()
if [ -f "$ZRODLO" ]; then
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[A-Z_]+$ ]] || continue
        OBECNE["$k"]="${v%\"}"; OBECNE["$k"]="${OBECNE[$k]#\"}"
    done < "$ZRODLO"
fi

zamaskuj() {
    local v="$1"
    [ ${#v} -le 8 ] && { printf '********'; return; }
    printf '%s…%s' "${v:0:4}" "${v: -4}"
}

# zapytaj NAZWA "opis" [domyślna-jeśli-brak] [cichy]
zapytaj() {
    local nazwa="$1" opis="$2" gdy_brak="${3:-}" cichy="${4:-}" stara="${OBECNE[$1]:-}" nowa=""
    echo
    echo "  $opis"
    if [ -n "$stara" ]; then
        echo "  obecna: $(zamaskuj "$stara")   [Enter = bez zmian]"
    elif [ -n "$gdy_brak" ]; then
        echo "  proponowana: $(zamaskuj "$gdy_brak")   [Enter = przyjmij]"
        stara="$gdy_brak"
    else
        echo "  wymagana — nie była jeszcze podana"
    fi
    if [ -n "$cichy" ]; then
        read -rsp "  > " nowa; echo
    else
        read -rp "  > " nowa
    fi
    if [ -z "$nowa" ]; then
        [ -n "$stara" ] || { echo "  ta wartość jest wymagana" >&2; return 1; }
        nowa="$stara"
    fi
    OBECNE["$nazwa"]="$nowa"
}

echo "== Sekrety =="
echo "  źródło: $ZRODLO"

zapytaj PROXMOX_API_TOKEN \
    "Token API Proxmoksa (root@pam!nazwa=UUID). Tworzy go: ssh pve 'pveum user token add root@pam terraform --privsep 0'" \
    "" cicho

_klucz=""
[ -f "$HOME/.ssh/id_ed25519.pub" ] && _klucz="$(cat "$HOME/.ssh/id_ed25519.pub")"
zapytaj SSH_PUBLIC_KEY \
    "Klucz publiczny wpuszczany na maszynę z k3s" \
    "$_klucz"

zapytaj SEC_USER_AGENT \
    "Identyfikacja dla SEC EDGAR — 'Imię Nazwisko adres@email'. Bez tego SEC odrzuca żądania." \
    ""

# ── zapis źródła ──────────────────────────────────────────────────────────────
umask 077
{
    echo "# Generowane przez scripts/setup.sh. Poza gitem — patrz .gitignore."
    echo "# Jedyne miejsce, w którym te wartości są wpisane ręcznie."
    for k in PROXMOX_API_TOKEN SSH_PUBLIC_KEY SEC_USER_AGENT; do
        printf '%s="%s"\n' "$k" "${OBECNE[$k]}"
    done
} > "$ZRODLO"
chmod 600 "$ZRODLO"
echo
echo "  zapisane: $ZRODLO (600)"

# ── rozprowadzenie: Terraform ─────────────────────────────────────────────────
echo
echo "== terraform/cluster =="
TFV="$ROOT/terraform/cluster/secrets.auto.tfvars"
{
    echo "# GENEROWANE przez scripts/setup.sh — nie edytuj ręcznie."
    echo "# Źródłem jest .secrets.env w korzeniu repo."
    echo
    printf 'proxmox_api_token = "%s"\n\n' "${OBECNE[PROXMOX_API_TOKEN]}"
    printf 'ssh_public_keys = [\n  "%s",\n]\n' "${OBECNE[SSH_PUBLIC_KEY]}"
} > "$TFV"
chmod 600 "$TFV"
echo "  zapisane: $TFV"

# ── rozprowadzenie: Secret w klastrze ─────────────────────────────────────────
echo
echo "== klaster =="
if [ -z "${KUBECONFIG:-}" ] && [ -f "$ROOT/kubeconfig" ]; then
    export KUBECONFIG="$ROOT/kubeconfig"
fi

if ! command -v kubectl >/dev/null; then
    echo "  pominięte: brak kubectl"
elif ! kubectl cluster-info >/dev/null 2>&1; then
    echo "  pominięte: klaster nieosiągalny (jeszcze go nie ma? uruchom najpierw cluster/tofu-apply.sh)"
else
    # --dry-run + apply zamiast create: to jest cała sztuczka na idempotencję, bo samo
    # `create secret` wywala się, gdy sekret już istnieje.
    kubectl create secret generic suwalski-sec \
        --namespace default \
        --from-literal=SEC_USER_AGENT="${OBECNE[SEC_USER_AGENT]}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    echo "  Secret suwalski-sec w przestrzeni default: aktualny"
fi

echo
echo "== Dalej =="
echo "  cd terraform/cluster  && tofu init    # jeśli jeszcze nie było"
echo "  cd terraform/platform && tofu init"
echo "  ./scripts/cluster/tofu-apply.sh"
