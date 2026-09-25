#!/usr/bin/env bash
# Przygotowanie PLATFORMY na świeżo sklonowanym repo. Idempotentne — uruchamiaj ile chcesz.
#
# Kroki: narzędzia (just) → sekrety platformy → ich rozprowadzenie.
#
# Tylko to, co wspólne dla całego klastra. Sekrety projektów (maile osób z dostępem, hasła
# aplikacji) mają własne skrypty w scripts/projects/<projekt>/[<środowisko>/]setup.sh —
# ten skrypt ich nie dotyka.
#
#   .secrets/platform.env ──┬──>  terraform/cluster/secrets.auto.tfvars   (Proxmox, SSH)
#                           ├──>  terraform/edge/secrets.auto.tfvars      (token Cloudflare)
#                           ├──>  terraform/edge/access/admin.json        (grupa „admin”: Ty)
#                           └──>  Secret cloudflared-token w klastrze*
#
#   * token tunelu nie pochodzi z .secrets/, tylko z wyjścia terraform/edge — powstaje
#     przy `just edge apply`. Dlatego po pierwszym apply edge uruchom ten skrypt jeszcze raz.
#
# ⚠ Przejściowe. Docelowo sekrety mają leżeć w gicie zaszyfrowane — patrz TODO.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

# ── narzędzia ─────────────────────────────────────────────────────────────────
# Najpierw, bo wszystko po setupie idzie przez `just`. Brak just nie blokuje sekretów —
# rozprowadzamy je i tak, a ostrzeżenie zostaje na ekranie.
echo "== Narzędzia =="
"$ROOT/scripts/.internal/install-just.sh" \
    || echo "  uwaga: bez just nie zadziała żadne \`just ...\` — sekrety rozprowadzam i tak" >&2

# ── sekrety platformy ─────────────────────────────────────────────────────────
echo
echo "== Sekrety platformy =="
migruj_stary_env
wczytaj_zrodlo platform
echo "  źródło: ${ZRODLO#"$ROOT"/}"

zapytaj PROXMOX_API_TOKEN \
    "Token API Proxmoksa (root@pam!nazwa=UUID). Tworzy go: ssh pve 'pveum user token add root@pam terraform --privsep 0'" \
    "" cicho

_klucz=""
[ -f "$HOME/.ssh/id_ed25519.pub" ] && _klucz="$(cat "$HOME/.ssh/id_ed25519.pub")"
zapytaj SSH_PUBLIC_KEY \
    "Klucz publiczny wpuszczany na maszynę z k3s" \
    "$_klucz"

zapytaj CLOUDFLARE_API_TOKEN \
    "Token API Cloudflare dla terraform/edge. Uprawnienia: docs/edge/guide/edge-4-sekrety.md" \
    "" cicho

zapytaj ACCESS_ADMIN \
    "Twój mail — grupa 'admin' w Cloudflare Access (to, co tylko dla Ciebie, np. środowiska dev)" \
    ""

echo
zapisz_zrodlo PROXMOX_API_TOKEN SSH_PUBLIC_KEY CLOUDFLARE_API_TOKEN ACCESS_ADMIN

# ── rozprowadzenie: terraform/cluster ─────────────────────────────────────────
echo
echo "== terraform/cluster =="
TFV="$ROOT/terraform/cluster/secrets.auto.tfvars"
(
    umask 077
    {
        echo "# GENEROWANE przez scripts/setup.sh — nie edytuj ręcznie."
        echo "# Źródłem jest .secrets/platform.env."
        echo
        printf 'proxmox_api_token = "%s"\n\n' "${OBECNE[PROXMOX_API_TOKEN]}"
        printf 'ssh_public_keys = [\n  "%s",\n]\n' "${OBECNE[SSH_PUBLIC_KEY]}"
    } > "$TFV"
)
echo "  zapisane: ${TFV#"$ROOT"/}"

# ── rozprowadzenie: terraform/edge ────────────────────────────────────────────
echo
echo "== terraform/edge =="
TFV="$ROOT/terraform/edge/secrets.auto.tfvars"
(
    umask 077
    {
        echo "# GENEROWANE przez scripts/setup.sh — nie edytuj ręcznie."
        echo "# Źródłem jest .secrets/platform.env. Grupy dostępu są w access/*.json."
        echo
        printf 'cloudflare_api_token = "%s"\n' "${OBECNE[CLOUDFLARE_API_TOKEN]}"
    } > "$TFV"
)
echo "  zapisane: ${TFV#"$ROOT"/}"
zapisz_grupe admin "${OBECNE[ACCESS_ADMIN]}"

# ── rozprowadzenie: klaster ───────────────────────────────────────────────────
echo
echo "== klaster =="
if klaster_dostepny; then
    # Token tunelu: z wyjścia terraform/edge, nie z .secrets/ — powstaje przy apply edge.
    # Sprawdzamy przez -json: przy pustym stanie `output -raw` wypisuje ostrzeżenie na
    # stdout i kończy zerem, więc do Secretu trafiłby tekst ostrzeżenia.
    EDGE="$ROOT/terraform/edge"
    if [ -d "$EDGE/.terraform" ] && (cd "$EDGE" && tofu output -json tunnel_token >/dev/null 2>&1); then
        secret cloudflared cloudflared-token "token=$(cd "$EDGE" && tofu output -raw tunnel_token)"
    else
        echo "  pominięte: token tunelu (tunelu jeszcze nie ma — najpierw: just edge apply)"
    fi
fi

echo
echo "== Dalej =="
echo "  projekty:  scripts/projects/<projekt>/[<środowisko>/]setup.sh — każdy swoje sekrety"
echo "  init:      (cd terraform/<cluster|platform|edge> && tofu init)   # jeśli jeszcze nie było"
echo "  potem:     just"
